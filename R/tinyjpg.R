#' @rdname tinyimg
#' @export
tinyjpg = function(
  input, output = tiny_output, quality = 75L,
  recursive = TRUE, verbose = TRUE
) {
  if (identical(output, tiny_output))
    output = function(x) tiny_output(x, quality = quality)
  paths = tinyopt_files(input, output, rx_jpg, recursive)
  if (length(paths$input)) tinyjpg_impl(
    paths$input, paths$output, as.numeric(quality), verbose
  )
  invisible(paths$output)
}
