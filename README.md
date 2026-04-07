# tinyimg

<!-- badges: start -->

[![R-CMD-check](https://github.com/yihui/tinyimg/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/yihui/tinyimg/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

An R package for optimizing and compressing images using Rust libraries.
Supports PNG optimization via [exoquant](https://github.com/exoticorn/exoquant-rs)
(lossy palette reduction) and [oxipng](https://github.com/oxipng/oxipng) (lossless
optimization), and JPEG re-encoding via [mozjpeg](https://github.com/mozilla/mozjpeg).

## Installation

You can install the development version of {tinyimg} from r-universe.dev:

```r
install.packages("tinyimg", repos = "https://yihui.r-universe.dev")
```

## Usage

### Optimize any images

```r
library(tinyimg)

# Optimize all images in a directory (PNG and JPEG)
tinyimg("path/to/directory")

# Optimize specific files (mixed formats)
tinyimg(c("photo.jpg", "diagram.png"))
```

### PNG optimization

```r
# Create a test PNG
tmp = tempfile()
png(tmp, width = 400, height = 400)
plot(1:10)
dev.off()

# Optimize with different levels (lossless)
tinypng(tmp, paste0(tmp, "-o1.png"), level = 1)
tinypng(tmp, paste0(tmp, "-o6.png"), level = 6)
# Lossy
tinypng(tmp, paste0(tmp, "-lossy.png"), lossy = 2.3)
```

### JPEG optimization

```r
# Create a test JPEG
tmp = tempfile(fileext = ".jpg")
jpeg(tmp, width = 400, height = 400)
plot(1:10)
dev.off()

# Optimize with default quality (75)
tinyjpg(tmp)

# Optimize to a new file at a lower quality
tinyjpg(tmp, paste0(tmp, "-q60.jpg"), quality = 60)
```

### Optimization levels and quality

For PNG, the `level` parameter controls the optimization level (0-6):

- `0`: Fast optimization with minimal compression
- `2`: Default - good balance between speed and compression
- `6`: Maximum optimization - best compression but slower

For JPEG, the `quality` parameter (0-100) controls quality vs. file size:

- `75`: Default - good balance between quality and file size
- `60` and below: Smaller files with visible JPEG artefacts
- `90` and above: Near-original quality, larger files

See the [benchmark results](https://pkg.yihui.org/tinyimg/examples/benchmark.html) for
detailed comparisons, and `?tinyimg`, `?tinypng`, `?tinyjpg` for full documentation.

## For Package Developers

When installing from GitHub via `remotes::install_github("yihui/tinyimg")`, the package will automatically create the vendor directory if Rust is installed on your system.

If you're developing and need to manually create the vendor directory:

```bash
# Run the update script to create vendor/ directory
./src/rust/update-vendor.sh
```

This creates the local `vendor/` directory needed for development. Neither `vendor/` nor `vendor.tar.xz` are tracked in git.

## License

MIT License. See LICENSE file for details.
