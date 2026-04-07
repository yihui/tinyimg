# Vendor Patches

This directory contains patches applied to vendored Rust dependencies after
`cargo vendor`. They are applied automatically by `update-vendor.sh`.

## Patches

### `extendr-ffi-src-lib.rs.patch`

Gates `R_MissingArg` as `#[cfg(r_4_5)]` (only declared as extern static for
R >= 4.5 where it is part of the public C API) and removes `R_UnboundValue`
entirely (it is non-API in all R versions).

### `extendr-api-build.rs.patch`

Propagates the `r_4_5` cfg flag from `extendr-ffi` to `extendr-api` by reading
`DEP_R_R_VERSION_MINOR` and emitting `cargo:rustc-cfg=r_4_5` for R >= 4.5.

### `extendr-api-src-robj-rinternals.rs.patch`

Replaces pointer-identity checks for `R_MissingArg` and `R_UnboundValue` in
`is_missing_arg()` and `is_unbound_value()` with structural `PRINTNAME` checks
that work across all R versions without referencing non-API extern statics:

- `R_MissingArg` is a `SYMSXP` whose `PRINTNAME` is a zero-length `CHARSXP`
- `R_UnboundValue` is a `SYMSXP` whose `PRINTNAME` is `R_NilValue` (`NILSXP`)

### `extendr-api-src-wrapper-symbol.rs.patch`

Gates `missing_arg()` for `#[cfg(r_4_5)]` only (where `R_MissingArg` is API),
and removes `unbound_value()` entirely (would require the non-API
`R_UnboundValue`). Updates tests accordingly.

### `extendr-api-src-prelude.rs.patch`

Updates the prelude re-exports to match the gated `missing_arg` and removed
`unbound_value` symbols.

## Dropping these patches

Once upstream `extendr-api`/`extendr-ffi` fix `R_MissingArg` and
`R_UnboundValue` API compliance (tracked at
<https://github.com/extendr/extendr/issues>), these patches can be dropped:

1. Delete the relevant `.patch` files from this directory.
2. Remove the corresponding patch application lines from `update-vendor.sh`.
3. Run `./src/rust/update-vendor.sh` and verify the build/check still passes.
