#' Optimize PNG images
#'
#' Optimize PNG images using the oxipng Rust library. This function compresses
#' PNG files without losing quality.
#'
#' @param input Path to the input PNG file.
#' @param output Path to the output PNG file. If `NULL` (default), the input
#'   file will be overwritten.
#' @param level Optimization level (0-6). Higher values result in better
#'   compression but take longer. Default is 2.
#'
#' @return Invisibly returns the path to the output file.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Optimize a PNG file in-place
#' optim_png("image.png")
#'
#' # Optimize and save to a different file
#' optim_png("input.png", "output.png")
#'
#' # Use maximum optimization
#' optim_png("image.png", level = 6)
#' }
optim_png = function(input, output = NULL, level = 2L) {
  # Validate input file
  if (!file.exists(input)) {
    stop("Input file does not exist: ", input)
  }
  
  # Use input as output if output is not specified
  if (is.null(output)) {
    output = input
  }
  
  # Validate level
  level = as.integer(level)
  if (level < 0 || level > 6) {
    stop("Optimization level must be between 0 and 6")
  }
  
  # Call Rust function
  result = optim_png_impl(
    normalizePath(input, mustWork = TRUE),
    normalizePath(output, mustWork = FALSE),
    level
  )
  
  invisible(output)
}
