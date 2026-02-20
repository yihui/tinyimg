# tinyimg

<!-- badges: start -->

[![R-CMD-check](https://github.com/yihui/tinyimg/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/yihui/tinyimg/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

An R package for optimizing and compressing images using Rust libraries. Currently supports PNG optimization via [exoquant](https://github.com/exoticorn/exoquant-rs) (lossy palette reduction) and [oxipng](https://github.com/oxipng/oxipng) (lossless optimization).

## Installation

You can install the development version of tinyimg from GitHub:

```r
# install.packages("remotes")
remotes::install_github("yihui/tinyimg")
```

## Usage

### Basic PNG optimization

```r
library(tinyimg)

# Create a test PNG
tmp = tempfile()
png(tmp, width = 400, height = 400)
plot(1:10)
dev.off()

# Optimize with different levels
tinypng(tmp, paste0(tmp, "-o1.png"), level = 1)
tinypng(tmp, paste0(tmp, "-o6.png"), level = 6)
tinypng(tmp, paste0(tmp, "-lossy.png"), lossy = 3)
```

### Directory optimization

```r
# Optimize all PNGs in a directory
optim_png("path/to/directory")
```

### Optimization levels

The `level` parameter controls the optimization level (0-6):

- `0`: Fast optimization with minimal compression
- `2`: Default - good balance between speed and compression
- `6`: Maximum optimization - best compression but slower

See the [benchmark results](https://pkg.yihui.org/tinyimg/examples/benchmark.html) for detailed comparisons of optimization levels and `?optim_png` for full documentation.

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
