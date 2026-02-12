# optimg

[![R-CMD-check](https://github.com/yihui/optimg/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/yihui/optimg/actions/workflows/R-CMD-check.yaml)

An R package for optimizing and compressing images using Rust libraries. Currently supports PNG optimization via the [oxipng](https://github.com/shssoichiro/oxipng) crate.

## Installation

You can install the development version of optimg from GitHub:

```r
# install.packages("remotes")
remotes::install_github("yihui/optimg")
```

## Requirements

- R (>= 3.5.0)
- Rust/Cargo (>= 1.56.0)

The package includes vendored Rust dependencies per CRAN policy, so you don't need internet access during installation.

## Usage

### Basic PNG optimization

```r
library(optimg)

# Optimize a PNG file in-place (overwrites the original)
optim_png("path/to/image.png")

# Optimize and save to a different file
optim_png("input.png", "output.png")

# Use maximum optimization (slower but better compression)
optim_png("image.png", level = 6)

# Use fast optimization
optim_png("image.png", level = 0)
```

### Optimization levels

The `level` parameter controls the optimization level (0-6):

- `0`: Fast optimization with minimal compression
- `2`: Default - good balance between speed and compression
- `6`: Maximum optimization - best compression but slower

## For Package Developers

### Updating Rust Dependencies

The Rust dependencies are vendored in `src/rust/vendor/` per CRAN policy. To update them:

```bash
# Run the update script
./update-vendor.sh
```

Or manually:

```bash
cd src/rust

# Update dependencies
cargo update

# Re-vendor without versioned directories
rm -rf vendor
cargo vendor

# Trim non-essential files (automated in update-vendor.sh)
find vendor -name ".github" -type d -exec rm -rf {} + 2>/dev/null || true
find vendor -name ".cargo" -type d -exec rm -rf {} + 2>/dev/null || true
# ... (see update-vendor.sh for complete list)

# Commit the changes
git add vendor Cargo.lock
git commit -m "Update vendored Rust dependencies"
```

### Building from Source

```r
# Install dependencies
install.packages(c("devtools", "roxygen2"))

# Build and install
devtools::install()
```

### Generating Documentation

The package uses roxygen2 with markdown support for documentation:

```r
# Update documentation
roxygen2::roxygenise()

# Or use devtools
devtools::document()
```

The documentation is generated from roxygen2 comments in the R source files. After modifying any `#'` comments in the R files, run the commands above to regenerate the `.Rd` files in the `man/` directory.

### Running Tests

```r
# The package uses testit for testing
library(testit)
source("tests/test-all.R")
```

## Technical Details

This package uses:

- **rextendr**: For Rust/R integration
- **oxipng**: Rust library for lossless PNG optimization
- **Vendored dependencies**: All Rust crates are included per CRAN policy

The package follows R coding style conventions:
- Uses `=` for assignment instead of `<-`
- Comprehensive documentation with roxygen2
- Automated testing with testit

## License

MIT License. See LICENSE file for details.
