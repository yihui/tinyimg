#!/usr/bin/env Rscript
# Process one assigned slice of CRAN packages and save results to a CSV.
#
# Reads the remaining.csv produced by cran-png-savings-setup.R, takes the
# rows for this job's slice, and processes each package sequentially (no
# internal parallelism) to keep CPU/memory usage predictable.
#
# For each package the script measures:
#   - direct .png / .apng files
#   - base64-encoded PNGs embedded in .html files (e.g. vignettes)
#
# Environment variables:
#   CRAN_MIRROR   – default https://cloud.r-project.org
#   CACHE_DIR     – directory that holds remaining.csv; results are written
#                   here too (default ~/.cran-savings-cache)
#   JOB_INDEX     – zero-based slice index (required)
#   PKGS_PER_JOB  – packages per slice (default 1000)

suppressPackageStartupMessages({
  library(tinyimg)
  library(xfun)
})

mirror       = Sys.getenv("CRAN_MIRROR",  "https://cloud.r-project.org")
cache_dir    = Sys.getenv("CACHE_DIR",    path.expand("~/.cran-savings-cache"))
job_index    = as.integer(Sys.getenv("JOB_INDEX",    "0"))
pkgs_per_job = as.integer(Sys.getenv("PKGS_PER_JOB", "1000"))

remaining_file = file.path(cache_dir, "remaining.csv")
results_file   = file.path(cache_dir, sprintf("results-%d.csv", job_index))

if (!file.exists(remaining_file))
  stop("remaining.csv not found in CACHE_DIR: ", cache_dir)

remaining = read.csv(remaining_file, stringsAsFactors = FALSE)
start_row = job_index * pkgs_per_job + 1L
end_row   = min((job_index + 1L) * pkgs_per_job, nrow(remaining))

if (start_row > nrow(remaining)) {
  message(sprintf(
    "Job %d: no packages to process (start_row %d > %d total)",
    job_index, start_row, nrow(remaining)
  ))
  quit(save = "no")
}

my_pkgs = remaining[start_row:end_row, ]
message(sprintf(
  "Job %d: processing rows %d-%d (%d packages)",
  job_index, start_row, end_row, nrow(my_pkgs)
))

# ----- Helpers ---------------------------------------------------------------

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

# ----- Main loop (sequential – no internal parallelism) ----------------------

results = vector("list", nrow(my_pkgs))
for (k in seq_len(nrow(my_pkgs))) {
  message(sprintf("[%d/%d] %s %s",
    k, nrow(my_pkgs), my_pkgs$Package[k], my_pkgs$Version[k]))
  results[[k]] = process_package(my_pkgs$Package[k], my_pkgs$Version[k])
}

# ----- Save results ----------------------------------------------------------

result_df = do.call(rbind, Filter(is.data.frame, results))
if (is.null(result_df)) result_df = data.frame(
  package   = character(),
  version   = character(),
  orig_size = numeric(),
  opt_size  = numeric(),
  stringsAsFactors = FALSE
)
write.csv(result_df, results_file, row.names = FALSE)
message(sprintf(
  "Job %d: saved %d results to %s", job_index, nrow(result_df), results_file
))
