#' Optimize JPEG images
#'
#' Optimize JPEG files or directories of JPEG files by re-encoding them with
#' [mozjpeg](https://github.com/mozilla/mozjpeg)'s optimized Huffman coding
#' and quantization tables.
#'
#' Re-encoding at the specified `quality` level produces a file that is often
#' considerably smaller than the original without a perceptible quality loss
#' when `quality >= 75`. Lower values shrink files further at the cost of
#' visible JPEG artefacts.
#'
#' @param input Path to the input JPEG file or directory. If a directory is
#'   provided, all JPEG files in the directory (and subdirectories if
#'   `recursive = TRUE`) will be optimized.
#' @param output Path to the output JPEG file or directory, or a function that
#'   takes an input file path and returns an output path. When optimizing a
#'   directory, `output` should be a directory path or a function.
#' @param quality Quality level (0-100). Higher values preserve more detail
#'   but result in larger files. Default 75 is a good balance between quality
#'   and file size.
#' @param recursive When `input` is a directory, recursively process
#'   subdirectories.
#' @param verbose Print file size reduction info for each file.
#' @return Character vector of output file paths (invisibly).
#' @seealso [tinyimg()] to optimize both PNG and JPEG files at once.
#' @export
#' @examples
#' # Create a test JPEG
#' tmp = tempfile(fileext = ".jpg")
#' jpeg(tmp, width = 400, height = 400)
#' plot(1:10)
#' dev.off()
#'
#' # Optimize with default quality
#' tinyjpg(tmp)
#'
#' # Optimize to a new file at a specific quality
#' tinyjpg(tmp, paste0(tmp, "-q60.jpg"), quality = 60)
tinyjpg = function(
  input, output = identity, quality = 75L,
  recursive = TRUE, verbose = TRUE
) {
  paths = tinyopt_files(input, output, "\\.jpe?g$", recursive)
  if (length(paths$input)) tinyjpg_impl(
    paths$input, paths$output, as.numeric(quality), verbose
  )
  invisible(paths$output)
}
