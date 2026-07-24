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