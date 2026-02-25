#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

// Forward declaration of Rust wrapper function
// Mark as visible to override C_VISIBILITY setting
attribute_visible SEXP wrap__tinypng_impl(SEXP input, SEXP output, SEXP level, SEXP alpha, SEXP preserve, SEXP verbose, SEXP lossy);

// Registration table for R's .Call interface
static const R_CallMethodDef CallEntries[] = {
    {"wrap__tinypng_impl", (DL_FUNC) &wrap__tinypng_impl, 7},
    {NULL, NULL, 0}
};

// Forward declaration of extendr initialization
void R_init_tinyimg_extendr(DllInfo *dll);

// Main package initialization function
attribute_visible void R_init_tinyimg(DllInfo *dll) {
    // Register native routines
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    
    // Initialize extendr
    R_init_tinyimg_extendr(dll);
}
