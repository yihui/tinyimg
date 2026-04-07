#' Optimize images (PNG and JPEG)
#'
#' Optimize image files or a directory of image files. PNG files are optimized
#' via [tinypng()] and JPEG files via [tinyjpg()]. This is the recommended
#' entry point when you have a mix of image types or do not know the exact
#' formats in advance.
#'
#' @param input Path to an image file, a character vector of image file paths,
#'   or a directory. Supported formats: `.png`, `.apng`, `.jpg`, `.jpeg`.
#' @param output Path to the output file or directory, or a function that
#'   takes an input file path and returns an output path. When `input` is a
#'   directory or a vector, `output` should be a directory path or a function.
#' @param recursive When `input` is a directory, recursively process
#'   subdirectories.
#' @param verbose Print file size reduction info for each file.
#' @param level Passed to [tinypng()] as the PNG optimization level (0-6).
#' @param quality Passed to [tinyjpg()] as the JPEG quality (0-100).
#' @param ... Additional arguments passed to both [tinypng()] and [tinyjpg()].
#' @return Character vector of output file paths (invisibly).
#' @seealso [tinypng()] for PNG-specific options, [tinyjpg()] for JPEG-specific
#'   options.
#' @export
#' @examples
#' # Create test images
#' tmp_png = tempfile(fileext = ".png")
#' png(tmp_png, width = 400, height = 400)
#' plot(1:10)
#' dev.off()
#'
#' tmp_jpg = tempfile(fileext = ".jpg")
#' jpeg(tmp_jpg, width = 400, height = 400)
#' plot(1:10)
#' dev.off()
#'
#' # Optimize both in one call
#' tinyimg(c(tmp_png, tmp_jpg))
#'
#' # Optimize all images in a directory
#' d = tempfile()
#' dir.create(d)
#' file.copy(tmp_png, file.path(d, "plot.png"))
#' file.copy(tmp_jpg, file.path(d, "photo.jpg"))
#' tinyimg(d)
tinyimg = function(
  input, output = identity, recursive = TRUE, verbose = TRUE,
  level = 2L, quality = 75L, ...
) {
  if (length(input) == 1 && dir.exists(input)) {
    png_in = list.files(input, "\\.a?png$",  recursive = recursive,
                        full.names = TRUE, ignore.case = TRUE)
    jpg_in = list.files(input, "\\.jpe?g$",  recursive = recursive,
                        full.names = TRUE, ignore.case = TRUE)
    png_out = resolve_output(png_in, output, input)
    jpg_out = resolve_output(jpg_in, output, input)
  } else {
    is_png = grepl("\\.a?png$",  input, ignore.case = TRUE)
    is_jpg = grepl("\\.jpe?g$",  input, ignore.case = TRUE)
    png_in  = input[is_png]
    jpg_in  = input[is_jpg]
    if (is.function(output)) {
      png_out = output(png_in)
      jpg_out = output(jpg_in)
    } else {
      png_out = output[is_png]
      jpg_out = output[is_jpg]
    }
  }
  if (length(png_in)) tinypng(
    png_in, png_out, level = level, recursive = FALSE, verbose = verbose, ...
  )
  if (length(jpg_in)) tinyjpg(
    jpg_in, jpg_out, quality = quality, recursive = FALSE, verbose = verbose
  )
  invisible(c(png_out, jpg_out))
}

# Map output paths for a subdirectory's files given the root input directory.
resolve_output = function(files, output, input_dir) {
  if (!length(files)) return(files)
  if (is.function(output)) return(output(files))
  # output is a directory: preserve relative paths under that directory
  # +2L: skip input_dir length and the trailing path separator character
  rel = substring(files, nchar(input_dir) + 2L)
  file.path(output, rel)
}
