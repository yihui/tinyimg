#!/usr/bin/env Rscript
# Determine remaining CRAN packages and emit a GitHub Actions matrix.
#
# Reads the accumulated results CSV from a previous run (if any), queries the
# current CRAN package list, and writes two files:
#   results.csv   – cleaned-up copy of already-processed packages (cache)
#   remaining.csv – packages that still need to be processed
#
# It then outputs a JSON matrix {"index":[0,1,...,n-1]} so the caller can
# fan out to that many parallel worker jobs.
#
# Environment variables (all optional):
#   CRAN_MIRROR  – default https://cloud.r-project.org
#   CACHE_DIR    – directory that holds results.csv
#                  (default ~/.cran-savings-cache)
#   PKGS_PER_JOB – packages assigned to each matrix job (default 1000)
#   MAX_JOBS     – hard cap on the number of matrix jobs (default 256)

mirror       = Sys.getenv("CRAN_MIRROR",  "https://cloud.r-project.org")
cache_dir    = Sys.getenv("CACHE_DIR",    path.expand("~/.cran-savings-cache"))
pkgs_per_job = as.integer(Sys.getenv("PKGS_PER_JOB", "1000"))
max_jobs     = as.integer(Sys.getenv("MAX_JOBS",     "256"))

dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
csv_file       = file.path(cache_dir, "results.csv")
remaining_file = file.path(cache_dir, "remaining.csv")

# ----- Load CRAN package list ------------------------------------------------

message("Fetching CRAN package list from ", mirror, " ...")
pkg_db   = available.packages(repos = mirror, type = "source")
all_pkgs = as.data.frame(pkg_db[, c("Package", "Version"), drop = FALSE])
message(sprintf("Found %d packages on CRAN", nrow(all_pkgs)))

# ----- Resume: load accumulated results from previous runs -------------------

if (file.exists(csv_file)) {
  done = read.csv(csv_file, stringsAsFactors = FALSE)
  message(sprintf("Already processed: %d packages", nrow(done)))
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
# Drop stale rows whose package has since received a new CRAN version.
done = done[!done$package %in% remaining$Package, ]

message(sprintf("%d packages remaining to process", nrow(remaining)))

# ----- Persist updated done list and remaining list --------------------------

write.csv(done,      csv_file,       row.names = FALSE)
write.csv(remaining, remaining_file, row.names = FALSE)

# ----- Build matrix ----------------------------------------------------------

n_rem  = nrow(remaining)
n_jobs = if (n_rem == 0L) 0L else min(as.integer(ceiling(n_rem / pkgs_per_job)), max_jobs)
indices      = if (n_jobs > 0L) seq(0L, n_jobs - 1L) else integer(0)
matrix_json  = sprintf('{"index":[%s]}', paste(indices, collapse = ","))

message(sprintf("Matrix: %d job(s) of up to %d packages each", n_jobs, pkgs_per_job))

# ----- Signal GitHub Actions -------------------------------------------------

gha_out = Sys.getenv("GITHUB_OUTPUT", "")
if (nzchar(gha_out)) {
  cat(sprintf("matrix=%s\n",      matrix_json),           file = gha_out, append = TRUE)
  cat(sprintf("has_work=%s\n",    tolower(n_rem > 0L)),   file = gha_out, append = TRUE)
  cat(sprintf("n_remaining=%d\n", n_rem),                 file = gha_out, append = TRUE)
  cat(sprintf("total_pkgs=%d\n",  nrow(all_pkgs)),        file = gha_out, append = TRUE)
}
