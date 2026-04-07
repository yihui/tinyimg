#' tinyimg: Optimize and Compress Images
#'
#' The tinyimg package provides tools for optimizing and compressing images
#' using Rust libraries. Use [tinyimg()] for a convenient entry point that
#' handles both PNG and JPEG files, [tinypng()] for PNG-only optimization, or
#' [tinyjpg()] for JPEG-only optimization.
#' @keywords internal
#' @useDynLib tinyimg, .registration = TRUE
"_PACKAGE"
