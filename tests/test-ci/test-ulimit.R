library(testit)
library(tinyimg)

# Create a large PNG that requires significant memory to optimize (5000x5000 px)
large_png = tempfile(fileext = ".png")
png(large_png, width = 5000, height = 5000)
plot(runif(1000), runif(1000))
dev.off()

# Create a large JPEG for the same test
large_jpg = tempfile(fileext = ".jpg")
jpeg(large_jpg, width = 5000, height = 5000)
plot(runif(1000), runif(1000))
dev.off()

# Run a code snippet in an external Rscript process with virtual-memory limited
# to 1 GB via `ulimit -v`.  That is enough for R to start and load tinyimg, but
# may be insufficient to process a large image — which is exactly the condition
# that previously triggered abort() / core dump instead of an R error.
run_with_ulimit = function(code, vmem_kb = 1048576L) {
  script = tempfile(fileext = ".R")
  writeLines(code, script)
  on.exit(unlink(script))
  result = system2(
    "bash",
    c("-c", sprintf("ulimit -v %d; Rscript --vanilla '%s'", vmem_kb, script)),
    stdout = TRUE, stderr = TRUE
  )
  s = attr(result, "status")
  if (is.null(s)) 0L else as.integer(s)
}

# On Linux, a process killed by SIGABRT (signal 6) exits with status 128+6=134.
# Any other exit status (0 = success, 1 = R error, etc.) is acceptable.
SIGABRT_EXIT = 134L

assert("tinypng() propagates OOM as an error, not abort()", {
  exit_code = run_with_ulimit(sprintf(paste0(
    "library(tinyimg); ",
    "tryCatch(tinypng('%s', verbose = FALSE), error = function(e) message(e$message))"
  ), large_png))
  (exit_code != SIGABRT_EXIT)
})

assert("tinyjpg() propagates OOM as an error, not abort()", {
  exit_code = run_with_ulimit(sprintf(paste0(
    "library(tinyimg); ",
    "tryCatch(tinyjpg('%s', output = identity, verbose = FALSE), ",
    "         error = function(e) message(e$message))"
  ), large_jpg))
  (exit_code != SIGABRT_EXIT)
})
