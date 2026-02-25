#' Optimize PNG images
#'
#' Optimize PNG files or directories of PNG files using optional lossy palette
#' reduction and dithering before lossless compression.
#'
#' @param input Path to the input PNG file or directory. If a directory is provided,
#'   all PNG files in the directory (and subdirectories if `recursive = TRUE`)
#'   will be optimized.
#' @param output Path to the output PNG file or directory, or a function that
#'   takes an input file path and returns an output path. When optimizing a
#'   directory, `output` should be a directory path or a function.
#' @param level Optimization level (0-6). Higher values result in better
#'   compression but take longer.
#' @param lossy A numeric $$\Delta E$$ (delta E) threshold for perceptual color
#'   error in lossy preprocessing. Values `<= 0` mean lossless optimization only.
#'
#'   The lossy algorithm uses color difference in the
#'   International Commission on Illumination (CIE) 1976
#'   $$L^*a^*b^*$$ (often written as CIELAB or Lab) color space.
#'
#'   For a candidate palette size `n`, the image is quantized with `n` colors,
#'   then the color difference $$\Delta E_{76}$$ is computed between original and
#'   quantized pixels on a sample of at most 50,000 pixels. We use the 95th
#'   percentile of sampled $$\Delta E_{76}$$ values and bisection on `n` (1--256)
#'   to find the smallest palette size whose 95th percentile is `<= lossy`.
#'
#'   Rough interpretation of $$\Delta E_{76}$$ values:
#'   - `< 1`: typically imperceptible
#'   - `1 - 2`: perceptible through close inspection
#'   - `2 - 10`: perceptible at a glance
#'   - `10 - 50`: strong perceptual difference
#'   - `> 50`: very large color shift
#'
#'   In theory $$\Delta E_{76}$$ can exceed 100 (up to around 374 for extreme
#'   RGB pairs).
#' @param alpha Optimize transparent pixels for better compression. This is
#'   technically lossy but visually lossless.
#' @param preserve Preserve file permissions and timestamps. Ignored when
#'   lossy optimization is enabled (`lossy > 0`).
#' @param recursive When `input` is a directory, recursively process subdirectories.
#' @param verbose Print file size reduction info for each file.
#' @param ... Arguments passed to `tinypng()`.
#'
#' @return Character vector of output file paths (invisibly).
#' @references
#' CIE (1978). *Recommendations on Uniform Color Spaces, Color Difference
#' Equations, Psychometric Color Terms*. Supplement No. 2 to CIE Publication
#' No. 15 (E-1.3.1) 1971/(TC-1.3), Bureau Central de la CIE, Paris.
#'
#' Sharma, G., Wu, W., & Dalal, E. N. (2005). The CIEDE2000 color-difference
#' formula: Implementation notes, supplementary test data, and mathematical
#' observations. *Color Research & Application*, 30(1), 21--30.
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
#' tinypng(tmp, paste0(tmp, "-o1.png"), level = 1)
#' tinypng(tmp, paste0(tmp, "-o6.png"), level = 6)
#' tinypng(tmp, paste0(tmp, "-lossy.png"), lossy = 0.5)
#' @export
tinypng = function(
  input, output = identity, level = 2L, alpha = FALSE, preserve = TRUE,
  recursive = TRUE, verbose = TRUE, lossy = 0
) {
  # Resolve directory input to PNG file paths
  if (length(input) == 1 && dir.exists(input)) {
    files = list.files(input, "\\.a?png$", recursive = recursive)
    # Apply output function or construct output paths
    output = if (is.function(output)) {
      output(file.path(input, files))
    } else {
      file.path(output, files)
    }
    input = file.path(input, files)
  } else {
    if (is.function(output)) output = output(input)
  }
  lossy = as.numeric(lossy[1])
  if (length(input))
    optim_png_impl(
      input, output, as.integer(level), alpha, preserve, verbose, lossy
    )
  invisible(output)
}

#' @rdname tinypng
#' @export
optim_png = function(...) tinypng(...)
