#' Optimize PNG images
#'
#' Optimize PNG images using the **oxipng** Rust library. This function compresses
#' PNG files or directories of PNG files without losing quality (lossless compression).
#'
#' The function uses the oxipng library which implements various PNG optimization
#' techniques including:
#'
#' - IDAT recompression with multiple algorithms
#' - Bit depth reduction
#' - Color type reduction
#' - Palette reduction
#'
#' **Optimization levels:**
#'
#' - Level 0: Minimal optimization (fastest)
#' - Level 1-2: Fast optimization with good results
#' - Level 3-4: More thorough optimization
#' - Level 5-6: Maximum optimization (slowest, best compression)
#'
#' @param input Path to the input PNG file or directory. If a directory is provided,
#'   all PNG files in the directory (and subdirectories if `recursive = TRUE`)
#'   will be optimized.
#' @param output Path to the output PNG file or directory. If not specified,
#'   the input file(s) will be overwritten. When optimizing a directory,
#'   `output` must be a directory path.
#' @param level Optimization level (0-6). Higher values result in better
#'   compression but take longer.
#' @param alpha Optimize transparent pixels for better compression. This is
#'   technically lossy but visually lossless.
#' @param preserve Preserve file permissions and timestamps.
#' @param recursive When `input` is a directory, recursively process subdirectories.
#' @param verbose Print file size reduction info for each file.
#'
#' @return For single files, returns the output path. For directories, returns a
#'   character vector of all optimized files.
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
  input, output = input, level = 2L, alpha = FALSE, preserve = TRUE,
  recursive = TRUE, verbose = TRUE
) {
  # Check if input is a directory
  if (dir.exists(input)) {
    files = list.files(
      input, "\\.a?png$", recursive = recursive, ignore.case = TRUE
    )
    output_files = file.path(output, files)
    for (i in seq_along(files)) {
      optim_png(
        file.path(input, files[i]), output_files[i], level = level,
        alpha = alpha, preserve = preserve, verbose = verbose
      )
    }
    return(output_files)
  }

  # Validate input file
  if (!file.exists(input)) stop("Input file does not exist: ", input)

  # Create output directory if it doesn't exist
  output_dir = dirname(output)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  # Call Rust function
  optim_png_impl(input, output, as.integer(level), alpha, preserve, verbose)

  output
}
