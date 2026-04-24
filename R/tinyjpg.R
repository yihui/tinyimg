#' @rdname tinyimg
#' @export
tinyjpg = function(
  input, output = tiny_output, quality = 75, recursive = TRUE, verbose = TRUE,
  max_pixels = 2e8
) {
  paths = tinyopt_files(input, output, rx_jpg, recursive, quality = quality)
  if (length(paths$input)) tinyjpg_impl(
    paths$input, paths$output, as.numeric(quality), verbose, as.numeric(max_pixels)
  )
  invisible(paths$output)
}
