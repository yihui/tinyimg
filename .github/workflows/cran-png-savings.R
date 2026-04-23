#!/usr/bin/env Rscript
# Analyze PNG optimization potential across all CRAN packages.
#
# For each package it finds:
#   - direct .png / .apng files
#   - base64-encoded PNGs embedded in .html files (e.g. vignettes)
#
# Results are accumulated in a CSV so runs can be resumed across multiple
# GitHub Actions executions.  The script signals "time_limit_hit=true" via
# GITHUB_OUTPUT when it is about to exceed the configured time budget.
#
# Environment variables (all optional):
#   CRAN_MIRROR       – default https://cloud.r-project.org
#   CACHE_DIR         – directory that holds results.csv
#                       (default ~/.cran-savings-cache)
#   TIME_LIMIT_HOURS  – stop processing after this many hours (default 5.5)
#   MAX_PKGS          – cap the number of packages processed, useful for
#                       testing (0 = unlimited)

suppressPackageStartupMessages({
  library(tinyimg)
  library(parallel)
  library(xfun)
})

# ----- Configuration ---------------------------------------------------------

mirror     = Sys.getenv("CRAN_MIRROR",      "https://cloud.r-project.org")
cache_dir  = Sys.getenv("CACHE_DIR",        path.expand("~/.cran-savings-cache"))
time_limit = as.numeric(Sys.getenv("TIME_LIMIT_HOURS", "5.5")) * 3600
max_pkgs   = as.integer(Sys.getenv("MAX_PKGS", "0"))  # 0 = no limit

dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
csv_file   = file.path(cache_dir, "results.csv")
start_time = proc.time()[["elapsed"]]

elapsed_secs = function() proc.time()[["elapsed"]] - start_time

# ----- Helpers ---------------------------------------------------------------

# Download url to destfile, retrying up to `retries` times on failure.
download_retry = function(url, destfile, retries = 3L) {
  for (i in seq_len(retries)) {
    ok = tryCatch({
      download.file(url, destfile, quiet = TRUE, method = "libcurl")
      TRUE
    }, error = function(e) FALSE)
    if (ok) return(TRUE)
    if (i < retries) Sys.sleep(5 * i)
  }
  FALSE
}

# ----- Load CRAN package list ------------------------------------------------

message("Fetching CRAN package list from ", mirror, " ...")
pkg_db   = available.packages(repos = mirror, type = "source")
all_pkgs = data.frame(
  Package = pkg_db[, "Package"],
  Version = pkg_db[, "Version"],
  stringsAsFactors = FALSE
)
message(sprintf("Found %d packages on CRAN", nrow(all_pkgs)))

# ----- Resume from previous results ------------------------------------------

if (file.exists(csv_file)) {
  done = read.csv(csv_file, stringsAsFactors = FALSE)
  message(sprintf("Resuming: %d packages already processed", nrow(done)))
} else {
  done = data.frame(
    package   = character(),
    version   = character(),
    orig_size = numeric(),
    opt_size  = numeric(),
    stringsAsFactors = FALSE
  )
}

done_keys = paste(done$package, done$version, sep = "@")
all_keys  = paste(all_pkgs$Package, all_pkgs$Version, sep = "@")
remaining = all_pkgs[!all_keys %in% done_keys, ]
message(sprintf("%d packages remaining to process", nrow(remaining)))
# remove any done rows for packages with new versions
done = done[!done$package %in% remaining$Package, ]

if (max_pkgs > 0L && nrow(remaining) > max_pkgs)
  remaining = remaining[seq_len(max_pkgs), ]

# ----- Per-package processing ------------------------------------------------

process_package = function(pkg_name, pkg_version) {
  tmp_dir = tempfile(paste0("pkg_", pkg_name, "_"))
  dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  tarball      = paste0(pkg_name, "_", pkg_version, ".tar.gz")
  tarball_path = file.path(tmp_dir, tarball)
  base_url     = paste0(mirror, "/src/contrib/")
  archive_url  = paste0(mirror, "/src/contrib/Archive/", pkg_name, "/")

  ok = download_retry(paste0(base_url, tarball), tarball_path) ||
       download_retry(paste0(archive_url, tarball), tarball_path)

  if (!ok) {
    message(sprintf("  [SKIP] %s %s: download failed", pkg_name, pkg_version))
    return(data.frame(
      package = pkg_name, version = pkg_version,
      orig_size = NA_real_, opt_size = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  extract_dir = file.path(tmp_dir, "pkg")
  dir.create(extract_dir, showWarnings = FALSE)
  tryCatch(untar(tarball_path, exdir = extract_dir), error = function(e) NULL)
  unlink(tarball_path)  # free disk space early

  total_orig = 0
  total_opt  = 0

  # --- Direct PNG / APNG files ---
  png_files = list.files(
    extract_dir, pattern = "\\.a?png$",
    recursive = TRUE, ignore.case = TRUE, full.names = TRUE
  )
  for (f in png_files) {
    sz = file.size(f)
    if (is.na(sz) || sz == 0L) next
    opt_sz = tryCatch({
      tinypng(f, output = identity, level = 2L, verbose = FALSE)
      file.size(f)
    }, error = function(e) sz)
    total_orig = total_orig + sz
    total_opt  = total_opt  + opt_sz
  }

  # --- Base64-encoded PNGs embedded in HTML files (e.g. vignettes) ---
  html_files = list.files(
    extract_dir, pattern = "\\.html$",
    recursive = TRUE, ignore.case = TRUE, full.names = TRUE
  )
  b64_png_pfx = "data:image/(?:a?png);base64,"
  b64_png_re  = paste0(b64_png_pfx, "[A-Za-z0-9+/=]+")

  for (html_file in html_files) {
    fsz = file.size(html_file)
    if (is.na(fsz) || fsz > 50L * 1024L * 1024L) next  # skip files > 50 MB

    html_text = tryCatch(
      paste(readLines(html_file, warn = FALSE), collapse = "\n"),
      error = function(e) ""
    )
    if (!nzchar(html_text)) next

    m  = gregexpr(b64_png_re, html_text, perl = TRUE)
    ml = attr(m[[1]], "match.length")
    if (length(ml) == 0L || all(ml == -1L)) next

    starts  = m[[1]]
    lengths = ml

    for (k in seq_along(starts)) {
      if (starts[k] < 0L) next
      full_match = substr(html_text, starts[k], starts[k] + lengths[k] - 1L)
      b64 = sub(b64_png_pfx, "", full_match, perl = TRUE)
      b64 = gsub("\\s+", "", b64)
      if (!nzchar(b64)) next

      tmp_png = tempfile(fileext = ".png", tmpdir = tmp_dir)
      ok2 = tryCatch({
        raw_data = xfun::base64_decode(b64)
        if (length(raw_data) == 0L) stop("empty")
        writeBin(raw_data, tmp_png)
        TRUE
      }, error = function(e) FALSE)
      if (!ok2) next

      orig_sz = file.size(tmp_png)
      if (is.na(orig_sz) || orig_sz == 0L) { unlink(tmp_png); next }

      opt_sz = tryCatch({
        tinypng(tmp_png, output = identity, level = 2L, verbose = FALSE)
        file.size(tmp_png)
      }, error = function(e) orig_sz)

      total_orig = total_orig + orig_sz
      total_opt  = total_opt  + opt_sz
      unlink(tmp_png)
    }
  }

  savings_pct = if (total_orig > 0) (1 - total_opt / total_orig) * 100 else 0
  message(sprintf(
    "  %s %s: %s -> %s (%.1f%% savings)",
    pkg_name, pkg_version,
    xfun::format_bytes(total_orig),
    xfun::format_bytes(total_opt),
    savings_pct
  ))

  data.frame(
    package   = pkg_name,
    version   = pkg_version,
    orig_size = total_orig,
    opt_size  = total_opt,
    stringsAsFactors = FALSE
  )
}

# ----- Main processing loop --------------------------------------------------

n_cores    = max(1L, parallel::detectCores())
batch_size = n_cores * 2L
n_rem      = nrow(remaining)
time_limit_hit = FALSE

message(sprintf("Using %d core(s), batch size %d", n_cores, batch_size))

i = 1L
while (i <= n_rem) {
  if (elapsed_secs() >= time_limit) {
    message(sprintf(
      "Time limit of %.1f hours reached after processing %d packages",
      time_limit / 3600, nrow(done)
    ))
    time_limit_hit = TRUE
    break
  }

  j     = min(i + batch_size - 1L, n_rem)
  batch = remaining[i:j, ]

  message(sprintf(
    "[%d/%d] %.2fh elapsed — processing %s %s ...",
    i, n_rem, elapsed_secs() / 3600,
    batch$Package[1],
    if (nrow(batch) > 1L) sprintf("(+%d more)", nrow(batch) - 1L) else ""
  ))

  batch_results = if (n_cores > 1L) {
    parallel::mclapply(
      seq_len(nrow(batch)),
      function(k) process_package(batch$Package[k], batch$Version[k]),
      mc.cores   = n_cores,
      mc.preschedule = FALSE
    )
  } else {
    lapply(
      seq_len(nrow(batch)),
      function(k) process_package(batch$Package[k], batch$Version[k])
    )
  }

  new_rows = do.call(rbind, Filter(is.data.frame, batch_results))
  if (!is.null(new_rows) && nrow(new_rows) > 0L) {
    done = rbind(done, new_rows)
    write.csv(done, csv_file, row.names = FALSE)
  }

  i = j + 1L
}

# ----- Summary ---------------------------------------------------------------

message(sprintf(
  "Finished. %d packages in CSV. %.2f hours elapsed.",
  nrow(done), elapsed_secs() / 3600
))

if (nrow(done) > 0L) {
  tot_orig = sum(done$orig_size, na.rm = TRUE)
  tot_opt  = sum(done$opt_size,  na.rm = TRUE)
  message(sprintf(
    "Aggregate: %s -> %s (%s saved; %.1f%% savings)",
    xfun::format_bytes(tot_orig),
    xfun::format_bytes(tot_opt),
    xfun::format_bytes(tot_orig - tot_opt),
    if (tot_orig > 0) (1 - tot_opt / tot_orig) * 100 else 0
  ))
}

# ----- Signal GitHub Actions -------------------------------------------------

gha_out = Sys.getenv("GITHUB_OUTPUT", "")
if (nzchar(gha_out))
  cat(
    sprintf("time_limit_hit=%s\n", tolower(as.character(time_limit_hit))),
    file = gha_out, append = TRUE
  )
