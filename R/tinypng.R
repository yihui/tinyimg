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
tinyopt_files = function(input, output, pattern, recursive) {
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
  if (!length(input)) return(character(0))
  mapply(function(f, l, q) {
    ext  = tolower(tools::file_ext(f))
    base = tools::file_path_sans_ext(f)
    if (ext %in% c("png", "apng")) {
      if (l > 0) paste0(base, "_l", l, ".", ext) else f
    } else if (ext %in% c("jpg", "jpeg")) {
      if (q < 100) paste0(base, "_q", q, ".", ext) else f
    } else f
  }, input, lossy, quality, SIMPLIFY = TRUE, USE.NAMES = FALSE)
}

#' @rdname tinyimg
#' @export
tinypng = function(
  input, output = tiny_output, level = 2L, alpha = FALSE, preserve = TRUE,
  recursive = TRUE, verbose = TRUE, lossy = 0
) {
  if (identical(output, tiny_output))
    output = function(x) tiny_output(x, lossy = lossy)
  paths = tinyopt_files(input, output, rx_png, recursive)
  lossy = as.numeric(lossy[1])
  if (length(paths$input)) tinypng_impl(
    paths$input, paths$output, as.integer(level), alpha, preserve, verbose, lossy
  )
  invisible(paths$output)
}
