#!/usr/bin/env Rscript
# Merge all worker-job CSV artifacts with the accumulated cache results,
# write an updated combined CSV, print a summary, and signal GitHub Actions
# whether another workflow run is needed to finish the remaining packages.
#
# The results CSV has five columns:
#   package, version, orig_size, opt_size, lossy_size
# Old entries lacking lossy_size are back-filled with NA.
#
# Environment variables (all optional):
#   CRAN_MIRROR    – default https://cloud.r-project.org
#   CACHE_DIR      – directory that holds results.csv
#                    (default ~/.cran-savings-cache)
#   ARTIFACTS_DIR  – directory where downloaded worker artifacts live
#                    (default CACHE_DIR/artifacts)

suppressPackageStartupMessages(library(xfun))

mirror        = Sys.getenv("CRAN_MIRROR",   "https://cloud.r-project.org")
cache_dir     = Sys.getenv("CACHE_DIR",     path.expand("~/.cran-savings-cache"))
artifacts_dir = Sys.getenv("ARTIFACTS_DIR", file.path(cache_dir, "artifacts"))

dir.create(cache_dir,     showWarnings = FALSE, recursive = TRUE)
dir.create(artifacts_dir, showWarnings = FALSE, recursive = TRUE)

csv_file = file.path(cache_dir, "results.csv")

# ----- Load accumulated results from cache -----------------------------------

if (file.exists(csv_file)) {
  combined = read.csv(csv_file, stringsAsFactors = FALSE)
  if (!"lossy_size" %in% names(combined))
    combined$lossy_size = NA_real_
  message(sprintf("Loaded %d existing results from cache", nrow(combined)))
} else {
  combined = data.frame(
    package    = character(),
    version    = character(),
    orig_size  = numeric(),
    opt_size   = numeric(),
    lossy_size = numeric(),
    stringsAsFactors = FALSE
  )
}

# ----- Merge worker artifacts ------------------------------------------------

artifact_csvs = list.files(
  artifacts_dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE
)
message(sprintf("Found %d artifact CSV(s) in %s", length(artifact_csvs), artifacts_dir))

new_rows = do.call(rbind, lapply(artifact_csvs, function(f) {
  tryCatch({
    df = read.csv(f, stringsAsFactors = FALSE)
    if (!"lossy_size" %in% names(df))
      df$lossy_size = NA_real_
    df
  }, error = function(e) {
    message(sprintf("  Warning: could not read %s: %s", f, conditionMessage(e)))
    NULL
  })
}))

if (!is.null(new_rows) && nrow(new_rows) > 0L) {
  combined = rbind(combined, new_rows)
  # Keep the latest entry per package@version pair (fromLast keeps the most
  # recently added row when there are duplicates across runs).
  combined = combined[!duplicated(paste(combined$package, combined$version), fromLast = TRUE), ]
  message(sprintf("Combined total: %d packages", nrow(combined)))
  write.csv(combined, csv_file, row.names = FALSE)
} else {
  message("No new results from worker artifacts.")
}

# ----- Check completion against current CRAN list ----------------------------

message("Fetching CRAN package list for completion check ...")
pkg_db   = available.packages(repos = mirror, type = "source")
all_pkgs = as.data.frame(pkg_db[, c("Package", "Version"), drop = FALSE])
N_all    = nrow(all_pkgs)
N_done   = nrow(combined)

# ----- Summary ---------------------------------------------------------------

message(sprintf(
  "Finished. %d/%d packages in CSV.", N_done, N_all
))

if (N_done > 0L) {
  tot_orig  = sum(combined$orig_size,  na.rm = TRUE)
  tot_opt   = sum(combined$opt_size,   na.rm = TRUE)
  tot_lossy = sum(combined$lossy_size, na.rm = TRUE)
  message(sprintf(
    "Lossless: %s -> %s (%s saved; %.1f%% savings)",
    xfun::format_bytes(tot_orig),
    xfun::format_bytes(tot_opt),
    xfun::format_bytes(tot_orig - tot_opt),
    if (tot_orig > 0) (1 - tot_opt / tot_orig) * 100 else 0
  ))
  if (sum(!is.na(combined$lossy_size)) > 0L)
    message(sprintf(
      "Lossy:    %s -> %s (%s saved; %.1f%% savings)",
      xfun::format_bytes(tot_orig),
      xfun::format_bytes(tot_lossy),
      xfun::format_bytes(tot_orig - tot_lossy),
      if (tot_orig > 0) (1 - tot_lossy / tot_orig) * 100 else 0
    ))
  if (N_all > N_done) message(sprintf(
    "Estimated total lossless savings: %s",
    xfun::format_bytes((tot_orig - tot_opt) / N_done * N_all)
  ))
}

# ----- Signal GitHub Actions -------------------------------------------------

unfinished = N_done < N_all
gha_out    = Sys.getenv("GITHUB_OUTPUT", "")
if (nzchar(gha_out))
  cat(
    sprintf("unfinished=%s\n", tolower(as.character(unfinished))),
    file = gha_out, append = TRUE
  )
