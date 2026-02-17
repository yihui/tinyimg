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
#'   all PNG files in the directory (and subdirectories if `recursive = TRUE`)
#'   will be optimized.
#' @param output Path to the output PNG file or directory, or a function that
#'   takes an input file path and returns an output path. When optimizing a
#'   directory, `output` should be a directory path or a function.
#' @param level Optimization level (0-6). Higher values result in better
#'   compression but take longer.
#' @param alpha Optimize transparent pixels for better compression. This is
#'   technically lossy but visually lossless.
#' @param preserve Preserve file permissions and timestamps.
#' @param recursive When `input` is a directory, recursively process subdirectories.
#' @param verbose Print file size reduction info for each file.
#'
#' @return Character vector of output file paths (invisibly).
#' @export
#'
#' @examples
#' # Create a test PNG
#' tmp = tempfile()
#' png(tmp, width = 400, height = 400)
#' plot(1:10)
#' dev.off()
#'
#' # Optimize with different levels
#' optim_png(tmp, paste0(tmp, "-o1.png"), level = 1)
#' optim_png(tmp, paste0(tmp, "-o6.png"), level = 6)
optim_png = function(
  input, output = identity, level = 2L, alpha = FALSE, preserve = TRUE,
  recursive = TRUE, verbose = TRUE
) {
  # Handle empty input
  if (length(input) == 0) return(invisible(character(0)))
  
  # Check if input is a single directory
  if (length(input) == 1 && dir.exists(input)) {
    # Find PNG files in directory
    files = list.files(
      input, "\\.a?png$", recursive = recursive, ignore.case = TRUE
    )
    if (length(files) == 0) return(invisible(character(0)))
    
    # Construct full input paths
    input_paths = file.path(input, files)
    
    # Determine output paths
    if (is.function(output)) {
      output_paths = output(input_paths)
    } else {
      output_paths = file.path(output, files)
    }
  } else {
    # Handle single file or vector of files
    input_paths = input
    
    # Determine output paths
    if (is.function(output)) {
      output_paths = output(input_paths)
    } else if (length(output) == 1) {
      # Single output: only allowed with single input, or use output as a function
      # Otherwise it's ambiguous how to handle multiple inputs
      if (length(input_paths) == 1) {
        output_paths = output
      } else {
        stop("When providing multiple input files, 'output' must be a function, ",
             "vector of paths (same length as input), or omitted to use identity function")
      }
    } else {
      output_paths = output
    }
  }
  
  # Ensure output_paths has same length as input_paths
  if (length(output_paths) != length(input_paths)) {
    stop("Output length (", length(output_paths), 
         ") must match input length (", length(input_paths), ")")
  }
  
  # Validate all input files exist
  missing = input_paths[!file.exists(input_paths)]
  if (length(missing) > 0) {
    stop("Input file(s) do not exist: ", paste(missing, collapse = ", "))
  }
  
  # Create output directories if they don't exist
  output_dirs = unique(dirname(output_paths))
  for (d in output_dirs) {
    if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  }
  
  # Call Rust function with vectors
  optim_png_impl(
    input_paths, output_paths, as.integer(level), alpha, preserve, verbose
  )
  
  invisible(output_paths)
}
