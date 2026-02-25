# CHANGES IN tinyimg VERSION 0.3

- Added optional lossy PNG optimization before lossless oxipng optimization.

- Added `tinypng()` as the primary API and kept `optim_png()` as a wrapper alias.

- Updated benchmark examples for lossy optimization results, visual comparisons, and lossy-level plots.

# CHANGES IN tinyimg VERSION 0.2

## Initial CRAN release

This is the first CRAN release of tinyimg. The package provides tools for optimizing and compressing images using Rust libraries.

- PNG optimization via the oxipng Rust crate

- Support for single file and directory optimization

- Configurable optimization levels (0-6)

- Optional alpha channel optimization for transparent pixels

- Preservation of file permissions and timestamps

- Verbose output showing file size reduction

- Recursive directory processing
