#' tinyimg: Optimize and Compress Images
#'
#' The tinyimg package provides tools for optimizing and compressing images using
#' Rust libraries. Currently supports PNG optimization via the oxipng crate.
#'
#' ## Main Functions
#'
#' - [optim_png()]: Optimize PNG images without quality loss
#'
#' ## Optimization Levels
#'
#' The package supports optimization levels from 0 to 6:
#'
#' - **Level 0**: Fastest, minimal compression
#' - **Level 2**: Default, balanced speed and compression
#' - **Level 6**: Maximum compression, slower
#'
#' @section Author:
#' Yihui Xie
#'
#' @section See Also:
#' Useful links:
#' - <https://github.com/yihui/tinyimg>
#' - Report bugs at <https://github.com/yihui/tinyimg/issues>
#'
#' @keywords internal
#' @useDynLib tinyimg, .registration = TRUE
"_PACKAGE"
