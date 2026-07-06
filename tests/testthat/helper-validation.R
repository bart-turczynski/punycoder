expect_rejects_non_character <- function(fn, ...) {
  testthat::expect_error(fn(123, ...), "character vector")
  testthat::expect_error(fn(TRUE, ...), "character vector")
  testthat::expect_error(fn(list("test"), ...), "character vector")
}

# Build a string carrying raw bytes (typically ill-formed UTF-8) so the C++
# codec's UTF-8 validation paths can be exercised from R. The encoding is marked
# UTF-8 so the bytes reach the native layer verbatim, not reencoded.
raw_utf8 <- function(...) {
  s <- rawToChar(as.raw(c(...)))
  Encoding(s) <- "UTF-8"
  s
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
