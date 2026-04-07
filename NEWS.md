# CHANGES IN tinyimg VERSION 0.4

- Added `tinyjpg()` for JPEG optimization (using the `mozjpeg` Rust crate).

- Added `tinyimg()` as a general entry point for optimizing both PNG and JPEG
  files in a directory or a vector of paths.

- Added `tiny_output()` helper to generate safe output paths with lossy/quality
  suffixes (e.g., `foo_l2.3.png`, `foo_q70.jpg`), now the default `output` for
  all three optimizers.

- Fixed `non-API call to R` NOTEs (`R_UnboundValue` in R-devel, `R_MissingArg`
  in R-patched). The root cause was `Debug for extendr_api::Error` (auto-derived)
  referencing `Debug for Robj`, which references the non-API `R_MissingArg` and
  `R_UnboundValue` statics. The fix patches `extendr-api` to replace the derived
  `Debug for Error` with a custom implementation delegating to `Display`, and
  changes all `Display for Error` arms to use `robj.rtype()` instead of `{:?}` on
  `Robj` directly. The `#[extendr]` functions now return `()` and call
  `throw_r_error()` on failure.


# CHANGES IN tinyimg VERSION 0.3

- Added optional lossy PNG optimization before lossless oxipng optimization.

- Changed the primary API from `optim_png()` to `tinypng()`.

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
