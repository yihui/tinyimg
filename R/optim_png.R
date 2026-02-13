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
#'   all PNG files in the directory (and subdirectories if \code{recursive = TRUE})
#'   will be optimized.
#' @param output Path to the output PNG file or directory. If `NULL` (default), the
#'   input file(s) will be overwritten. When optimizing a directory, \code{output}
#'   must be either `NULL` or a directory path.
#' @param level Optimization level (0-6). Higher values result in better
#'   compression but take longer. Default is 2.
#' @param strip Strip metadata chunks. Options: `NULL` (keep all), `"safe"` (strip
#'   non-critical chunks except display-affecting ones), or `"all"` (strip all
#'   non-critical chunks). Default is `NULL`.
#' @param alpha Optimize transparent pixels for better compression. This is
#'   technically lossy but visually lossless. Default is `FALSE`.
#' @param interlace Interlacing mode: `"off"` (remove interlacing), `"on"` (apply
#'   Adam7 interlacing), or `"keep"` (preserve existing mode). Default is `"off"`.
#'   Note that interlacing can add 25-50% to file size.
#' @param fast Use fast compression evaluation. Recommended when using multiple
#'   filter types. Default is `FALSE`.
#' @param preserve Preserve file permissions and timestamps. Default is `TRUE`.
#' @param timeout Maximum time in seconds to spend optimizing each file. 0 means
#'   no limit. Default is 0.
#' @param recursive When `input` is a directory, recursively process subdirectories.
#'   Default is `FALSE`.
#'
#' @return Invisibly returns the path(s) to the output file(s). For directories,
#'   returns a character vector of all optimized files.
#' @export
#'
#' @examples
#' # Create a test PNG
#' tmp = tempfile(fileext = ".png")
#' png(tmp, width = 400, height = 400)
#' plot(1:10)
#' dev.off()
#'
#' # Optimize with different levels
#' optim_png(tmp, paste0(tmp, "-o1.png"), level = 1)
#' optim_png(tmp, paste0(tmp, "-o6.png"), level = 6)
#'
#' # Strip metadata for smaller files
#' optim_png(tmp, paste0(tmp, "-stripped.png"), strip = "safe")
#'
#' # Optimize transparent images
#' optim_png(tmp, paste0(tmp, "-alpha.png"), alpha = TRUE)
#'
#' # Optimize with timeout
#' optim_png(tmp, paste0(tmp, "-fast.png"), timeout = 5)
#'
#' # Optimize all PNGs in a directory
#' tmpdir = tempfile()
#' dir.create(tmpdir)
#' file.copy(tmp, file.path(tmpdir, "test1.png"))
#' file.copy(tmp, file.path(tmpdir, "test2.png"))
#' optim_png(tmpdir)
optim_png = function(input, output = NULL, level = 2L, strip = NULL,
                     alpha = FALSE, interlace = c("off", "on", "keep"),
                     fast = FALSE, preserve = TRUE, timeout = 0L,
                     recursive = FALSE) {
  # Match interlace argument
  interlace = match.arg(interlace)

  # Check if input is a directory
  if (dir.exists(input)) {
    # Find all PNG files
    pattern = "\\.png$|\\.apng$"
    files = list.files(input, pattern = pattern, full.names = TRUE,
                      recursive = recursive, ignore.case = TRUE)
    if (length(files) == 0) {
      warning("No PNG files found in directory: ", input)
      return(invisible(character(0)))
    }

    # Determine output paths
    if (is.null(output)) {
      # Optimize in place
      output_files = files
    } else {
      # Output to different directory
      if (!dir.exists(output)) dir.create(output, recursive = TRUE)
      # Preserve relative paths if recursive
      if (recursive) {
        rel_paths = sub(paste0("^", normalizePath(input), "/?"), "", normalizePath(files))
        output_files = file.path(output, rel_paths)
        # Create subdirectories if needed
        output_dirs = unique(dirname(output_files))
        for (d in output_dirs) {
          if (!dir.exists(d)) dir.create(d, recursive = TRUE)
        }
      } else {
        output_files = file.path(output, basename(files))
      }
    }

    # Optimize each file
    results = character(length(files))
    for (i in seq_along(files)) {
      optim_png(files[i], output_files[i], level = level, strip = strip,
               alpha = alpha, interlace = interlace, fast = fast,
               preserve = preserve, timeout = timeout, recursive = FALSE)
      results[i] = output_files[i]
    }
    return(invisible(results))
  }

  # Validate input file
  if (!file.exists(input)) stop("Input file does not exist: ", input)

  # Use input as output if output is not specified
  if (is.null(output)) output = input

  # Validate level
  level = as.integer(level)
  if (level < 0 || level > 6) stop("Optimization level must be between 0 and 6")

  # Validate timeout
  timeout = as.integer(timeout)
  if (timeout < 0) stop("Timeout must be non-negative")

  # Validate strip
  if (!is.null(strip)) {
    if (!strip %in% c("safe", "all")) {
      stop("strip must be NULL, 'safe', or 'all'")
    }
  }

  # Call Rust function
  result = optim_png_impl(
    normalizePath(input, mustWork = TRUE),
    normalizePath(output, mustWork = FALSE),
    level,
    if (is.null(strip)) NULL else strip,
    alpha,
    interlace,
    fast,
    preserve,
    timeout
  )

  invisible(output)
}
