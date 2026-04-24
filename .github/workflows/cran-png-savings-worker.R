#!/usr/bin/env Rscript
# Process one assigned slice of CRAN packages and save results to a CSV.
#
# Reads the remaining.csv produced by cran-png-savings-setup.R, takes the
# rows for this job's slice, and processes each package sequentially (no
# internal parallelism) to keep CPU/memory usage predictable.
#
# For each package the script measures lossless AND lossy (lossy=2.3) PNG
# optimisation savings.  PNG files larger than PNG_SIZE_THRESHOLD are run in
# a fresh R subprocess protected by ulimit -v so that pathologically large
# images (e.g. a 101 831 x 31 782 hex sticker that would expand to ~12 GB of
# raw pixels) cannot crash the main worker process.  If tinypng() exhausts
# the memory budget the corresponding column is left as NA.
#
# Both lossless and lossy results are written to separate temporary files;
# the original package file is never modified.
#
# Environment variables:
#   CRAN_MIRROR         - default https://cloud.r-project.org
#   CACHE_DIR           - directory that holds remaining.csv; results are
#                         written here too (default ~/.cran-savings-cache)
#   JOB_INDEX           - zero-based slice index (required)
#   PKGS_PER_JOB        - packages per slice (default 1000)
#   PNG_SIZE_THRESHOLD  - file-size threshold in bytes above which a PNG is
#                         processed in a subprocess (default 1048576 = 1 MiB).
#                         Chosen so that even a 250x compression-ratio image
#                         stays within half the available GHA memory inline.
#   MEM_LIMIT_PCT       - percentage of currently-available RAM to allow each
#                         subprocess (default 50). Uses ps::ps_system_memory()
#                         at startup; falls back to /proc/meminfo on Linux.

suppressPackageStartupMessages({
  library(tinyimg)
  library(xfun)
})

mirror             = Sys.getenv("CRAN_MIRROR",          "https://cloud.r-project.org")
cache_dir          = Sys.getenv("CACHE_DIR",            path.expand("~/.cran-savings-cache"))
job_index          = as.integer(Sys.getenv("JOB_INDEX",         "0"))
pkgs_per_job       = as.integer(Sys.getenv("PKGS_PER_JOB",      "1000"))
png_size_threshold = as.numeric(Sys.getenv("PNG_SIZE_THRESHOLD", "1048576"))  # 1 MiB
mem_limit_pct      = as.numeric(Sys.getenv("MEM_LIMIT_PCT",      "50"))

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

# ----- Compute subprocess memory limit (kilobytes for ulimit -v) -------------

mem_limit_kb = tryCatch({
  avail = ps::ps_system_memory()[["avail"]]
  as.integer(avail * mem_limit_pct / 100 / 1024)
}, error = function(e) {
  # Fallback: read /proc/meminfo (Linux-specific)
  tryCatch({
    lines = readLines("/proc/meminfo", warn = FALSE)
    kb    = as.integer(gsub("[^0-9]", "",
              grep("^MemAvailable:", lines, value = TRUE)[[1]]))
    as.integer(kb * mem_limit_pct / 100)
  }, error = function(e2) {
    message("Warning: could not read system memory; defaulting to 2 GiB limit")
    2L * 1024L * 1024L
  })
})
message(sprintf("Subprocess memory limit: %s (%.0f%% of available)",
                xfun::format_bytes(mem_limit_kb * 1024.0), mem_limit_pct))

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

# Run tinypng() in a subprocess with a virtual-memory cap (ulimit -v).
# Both lossless (lossy=0) and lossy (lossy=2.3) optimisations are attempted
# in a single Rscript invocation to amortise startup cost.  Output files that
# are not created indicate that the corresponding optimisation failed (e.g. OOM).
tinypng_subprocess = function(input, lossless_out, lossy_out) {
  script = tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(c(
    "library(tinyimg)",
    sprintf("try(tinypng(%s, %s, level=2L, verbose=FALSE))",
            deparse(input), deparse(lossless_out)),
    sprintf("try(tinypng(%s, %s, level=2L, verbose=FALSE, lossy=2.3))",
            deparse(input), deparse(lossy_out))
  ), script)
  cmd = sprintf("(ulimit -v %s; Rscript %s)", mem_limit_kb, shQuote(script))
  message("Running: ", cmd)
  system(cmd)
  invisible(NULL)
}

# Optimise a single PNG file losslessly and lossily.
# Returns a numeric vector c(opt_size, lossy_size) where NA means failure.
optimise_png = function(input, sz, tmp_dir) {
  lossless_out = tempfile(fileext = ".png", tmpdir = tmp_dir)
  lossy_out    = tempfile(fileext = ".png", tmpdir = tmp_dir)

  if (sz > png_size_threshold) {
    tinypng_subprocess(input, lossless_out, lossy_out)
  } else {
    tryCatch(
      tinypng(input, lossless_out, level = 2L, verbose = FALSE),
      error = function(e) NULL
    )
    tryCatch(
      tinypng(input, lossy_out, level = 2L, verbose = FALSE, lossy = 2.3),
      error = function(e) NULL
    )
  }

  opt_sz   = if (file.exists(lossless_out)) file.size(lossless_out) else NA_real_
  lossy_sz = if (file.exists(lossy_out))    file.size(lossy_out)    else NA_real_
  c(opt_sz, lossy_sz)
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
      package    = pkg_name, version = pkg_version,
      orig_size  = NA_real_, opt_size = NA_real_, lossy_size = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  extract_dir = file.path(tmp_dir, "pkg")
  dir.create(extract_dir, showWarnings = FALSE)
  tryCatch(untar(tarball_path, exdir = extract_dir), error = function(e) NULL)
  unlink(tarball_path)  # free disk space early

  total_orig  = 0
  total_opt   = 0
  total_lossy = 0

  # --- Direct PNG / APNG files ---
  png_files = list.files(
    extract_dir, pattern = "\\.a?png$",
    recursive = TRUE, ignore.case = TRUE, full.names = TRUE
  )
  for (f in png_files) {
    sz = file.size(f)
    if (is.na(sz) || sz == 0L) next

    sizes    = optimise_png(f, sz, tmp_dir)
    opt_sz   = sizes[1]
    lossy_sz = sizes[2]

    total_orig  = total_orig  + sz
    total_opt   = total_opt   + if (is.na(opt_sz))   sz else opt_sz
    total_lossy = total_lossy + if (is.na(lossy_sz))  sz else lossy_sz
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

      sizes     = optimise_png(tmp_png, orig_sz, tmp_dir)
      opt_sz2   = sizes[1]
      lossy_sz2 = sizes[2]

      total_orig  = total_orig  + orig_sz
      total_opt   = total_opt   + if (is.na(opt_sz2))   orig_sz else opt_sz2
      total_lossy = total_lossy + if (is.na(lossy_sz2))  orig_sz else lossy_sz2
      unlink(tmp_png)
    }
  }

  savings_pct = if (total_orig > 0) (1 - total_opt   / total_orig) * 100 else 0
  lossy_pct   = if (total_orig > 0) (1 - total_lossy / total_orig) * 100 else 0
  message(sprintf(
    "  %s %s: %s -> lossless %s (%.1f%%), lossy %s (%.1f%%)",
    pkg_name, pkg_version,
    xfun::format_bytes(total_orig),
    xfun::format_bytes(total_opt),   savings_pct,
    xfun::format_bytes(total_lossy), lossy_pct
  ))

  data.frame(
    package    = pkg_name,
    version    = pkg_version,
    orig_size  = total_orig,
    opt_size   = total_opt,
    lossy_size = total_lossy,
    stringsAsFactors = FALSE
  )
}

# ----- Main loop (sequential - no internal parallelism) ----------------------

results = vector("list", nrow(my_pkgs))
for (k in seq_len(nrow(my_pkgs))) {
  message(sprintf("[%d/%d] %s %s",
    k, nrow(my_pkgs), my_pkgs$Package[k], my_pkgs$Version[k]))
  results[[k]] = process_package(my_pkgs$Package[k], my_pkgs$Version[k])
}

# ----- Save results ----------------------------------------------------------

result_df = do.call(rbind, Filter(is.data.frame, results))
if (is.null(result_df)) result_df = data.frame(
  package    = character(),
  version    = character(),
  orig_size  = numeric(),
  opt_size   = numeric(),
  lossy_size = numeric(),
  stringsAsFactors = FALSE
)
write.csv(result_df, results_file, row.names = FALSE)
message(sprintf(
  "Job %d: saved %d results to %s", job_index, nrow(result_df), results_file
))
