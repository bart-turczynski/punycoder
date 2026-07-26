#include <R.h>
#include <Rinternals.h>
#include <stdlib.h> // for NULL
#include <R_ext/Rdynload.h>

/* Hand-maintained. Rcpp's compileAttributes() does NOT generate or update this
   file: it rewrites src/RcppExports.cpp and R/RcppExports.R only, and neither
   carries R_registerRoutines(). This is the sole native-routine registration
   point, and NAMESPACE has useDynLib(punycoder, .registration = TRUE).

   So every new // [[Rcpp::export]] needs TWO edits here by hand -- an extern
   declaration below and a matching row in CallEntries. Forgetting them is not a
   compile error; it surfaces at runtime as "symbol not found".

   Declare zero-argument entry points as (void), never (). In C, () means
   "unspecified arguments" and trips -Wstrict-prototypes. */

extern SEXP _punycoder_puny_encode_cpp(SEXP, SEXP);
extern SEXP _punycoder_puny_decode_cpp(SEXP, SEXP);
extern SEXP _punycoder_validate_domain_cpp(SEXP, SEXP);
extern SEXP _punycoder_backend_info_cpp(void);
extern SEXP _punycoder_compare_backends_cpp(SEXP, SEXP, SEXP);
extern SEXP _punycoder_host_normalize_cpp(SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP _punycoder_normalization_unicode_version_cpp(void);
extern SEXP _punycoder_unicode_versions_cpp(void);

static const R_CallMethodDef CallEntries[] = {
    {"_punycoder_puny_encode_cpp", (DL_FUNC) &_punycoder_puny_encode_cpp, 2},
    {"_punycoder_puny_decode_cpp", (DL_FUNC) &_punycoder_puny_decode_cpp, 2},
    {"_punycoder_validate_domain_cpp", (DL_FUNC) &_punycoder_validate_domain_cpp, 2},
    {"_punycoder_backend_info_cpp", (DL_FUNC) &_punycoder_backend_info_cpp, 0},
    {"_punycoder_compare_backends_cpp", (DL_FUNC) &_punycoder_compare_backends_cpp, 3},
    {"_punycoder_host_normalize_cpp", (DL_FUNC) &_punycoder_host_normalize_cpp, 5},
    {"_punycoder_normalization_unicode_version_cpp", (DL_FUNC) &_punycoder_normalization_unicode_version_cpp, 0},
    {"_punycoder_unicode_versions_cpp", (DL_FUNC) &_punycoder_unicode_versions_cpp, 0},
    {NULL, NULL, 0}
};

void R_init_punycoder(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
