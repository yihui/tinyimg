## Test environments

* Local Ubuntu 24.04, R 4.5.2
* GitHub Actions (ubuntu-latest, macOS-latest, windows-latest), R release and devel
* win-builder (R devel and release)

## R CMD check results

There were no ERRORs or WARNINGs.

There was 1 NOTE:

* New submission

This is expected for a first submission to CRAN.

## Downstream dependencies

There are currently no downstream dependencies for this package.

## Additional notes

This package uses Rust for image optimization. The package includes vendored Rust dependencies (via vendor.tar.xz in the source tarball) to comply with CRAN policies and ensure reproducible builds. The Rust compiler (rustc >= 1.56.0) and Cargo are required as SystemRequirements for building from source.

The package follows CRAN policies by:
- Limiting parallel jobs to 2 during Rust compilation
- Including all dependency sources in vendored form
- Providing proper copyright attribution for all Rust crates in inst/AUTHORS
- Using secure HTTPS URLs for all external references
