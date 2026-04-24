# Regex patterns for image file extensions (no leading ^ so list.files works)
rx_png = "\\.a?png$"
rx_jpg = "\\.jpe?g$"

#' Resolve input/output file paths for image optimization
#'
#' @param input Input path(s) or directory.
#' @param output Output path(s), directory, or function.
#' @param pattern Regex pattern for matching files in a directory.
#' @param recursive Recursively search subdirectories.
#' @return Named list with `input` and `output` character vectors (paths expanded).
#' @noRd
tinyopt_files = function(input, output, pattern, recursive, lossy = 0, quality = 75) {
  if (identical(output, tiny_output))
    output = function(x) tiny_output(x, lossy = lossy, quality = quality)
  if (length(input) == 1 && dir.exists(input)) {
    files = list.files(input, pattern, recursive = recursive, ignore.case = TRUE)
    output = if (is.function(output)) {
      output(file.path(input, files))
    } else {
      file.path(output, files)
    }
    input = file.path(input, files)
  } else {
    if (is.function(output)) output = output(input)
  }
  list(input = path.expand(input), output = path.expand(output))
}

#' @rdname tinyimg
#' @export
tiny_output = function(input, lossy = 0, quality = 75) {
  ext    = tolower(tools::file_ext(input))
  base   = tools::file_path_sans_ext(input)
  suffix = ifelse(
    ext %in% c("png", "apng") & lossy > 0, paste0("_l", lossy),
    ifelse(ext %in% c("jpg", "jpeg") & quality < 100, paste0("_q", quality), "")
  )
  sprintf("%s%s.%s", base, suffix, ext)
}

#' @rdname tinyimg
#' @export
tinypng = function(
  input, output = tiny_output, level = 2L, alpha = FALSE, preserve = TRUE,
  recursive = TRUE, verbose = TRUE, lossy = 0, max_pixels = 2e8
) {
  lossy = as.numeric(lossy[1])
  paths = tinyopt_files(input, output, rx_png, recursive, lossy = lossy)
  if (length(paths$input)) tinypng_impl(
    paths$input, paths$output, as.integer(level), alpha, preserve, verbose,
    lossy, as.numeric(max_pixels)
  )
  invisible(paths$output)
}
