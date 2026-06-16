expect_rejects_non_character <- function(fn, ...) {
  testthat::expect_error(fn(123, ...), "character vector")
  testthat::expect_error(fn(TRUE, ...), "character vector")
  testthat::expect_error(fn(list("test"), ...), "character vector")
}

# url_encode/url_decode/parse_url are deprecated (PUNY-vpegoytz) and emit a
# .Deprecated() warning on every call. The dedicated tests in test-urls.R assert
# that warning; the behavioural tests wrap their bodies in this muffler so the
# deprecation noise doesn't drown out (or get mistaken for) the warnings they
# actually exercise. Only the deprecatedWarning class is muffled, so NA-input
# warnings still surface for the tests that expect them.
suppress_url_deprecation <- function(code) {
  withCallingHandlers(
    code,
    deprecatedWarning = function(w) invokeRestart("muffleWarning")
  )
}
