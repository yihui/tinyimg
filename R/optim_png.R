#' Optimize PNG images
#'
#' Optimize PNG files or directories of PNG files using lossless compression.
#'
#' @param input Path to the input PNG file or directory. If a directory is provided,
#'   all PNG files in the directory (and subdirectories if `recursive = TRUE`)
#'   will be optimized.
#' @param output Path to the output PNG file or directory, or a function that
#'   takes an input file path and returns an output path. When optimizing a
#'   directory, `output` should be a directory path or a function.
#' @param level Optimization level (0-6). Higher values result in better
#'   compression but take longer.
#' @param alpha Optimize transparent pixels for better compression. This is
#'   technically lossy but visually lossless.
#' @param preserve Preserve file permissions and timestamps.
#' @param recursive When `input` is a directory, recursively process subdirectories.
#' @param verbose Print file size reduction info for each file.
#'
#' @return Character vector of output file paths (invisibly).
#' @export
#'
#' @examples
#' # Create a test PNG
#' tmp = tempfile()
#' png(tmp, width = 400, height = 400)
#' plot(1:10)
#' dev.off()
#'
#' # Optimize with different levels
#' optim_png(tmp, paste0(tmp, "-o1.png"), level = 1)
#' optim_png(tmp, paste0(tmp, "-o6.png"), level = 6)
optim_png = function(
  input, output = identity, level = 2L, alpha = FALSE, preserve = TRUE,
  recursive = TRUE, verbose = TRUE
) {
  # Resolve directory input to PNG file paths
  if (length(input) == 1 && dir.exists(input)) {
    files = list.files(input, "\\.a?png$", recursive = recursive)
    # Apply output function or construct output paths
    output = if (is.function(output)) {
      output(file.path(input, files))
    } else {
      file.path(output, files)
    }
    input = file.path(input, files)
  } else {
    if (is.function(output)) output = output(input)
  }
  if (length(input))
    optim_png_impl(input, output, as.integer(level), alpha, preserve, verbose)
  invisible(output)
}
