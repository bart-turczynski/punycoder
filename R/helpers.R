#' Validate that input is a character vector
#' @param x Value to check
#' @param arg Parameter name for error messages
#' @keywords internal
#' @noRd
.assert_character <- function(x, arg = "x") {
  if (!is.character(x)) {
    stop("'", arg, "' must be a character vector", call. = FALSE)
  }
}

#' Validate that input is a single logical flag
#' @param x Value to check
#' @param arg Parameter name for error messages
#' @keywords internal
#' @noRd
.assert_flag <- function(x, arg) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(arg, " must be TRUE or FALSE", call. = FALSE)
  }
}

#' Validate the UTS #46 normalization flag triple
#'
#' The same three flags gate `host_normalize()` and
#' `normalization_profile_info()`. Validation order is part of the contract:
#' a call passing several bad flags reports `check_hyphens` first.
#' @param check_hyphens,use_std3,verify_dns_length Values to check
#' @keywords internal
#' @noRd
.assert_normalize_flags <- function(check_hyphens, use_std3,
                                    verify_dns_length) {
  .assert_flag(check_hyphens, "check_hyphens")
  .assert_flag(use_std3, "use_std3")
  .assert_flag(verify_dns_length, "verify_dns_length")
}

#' Lexical predicate matching restricted to well-formed UTF-8
#'
#' Shared engine for `is_punycode()` and `is_idn()`, which promise a strictly
#' logical answer: an element that is not valid UTF-8 cannot be a match, so it
#' reports `FALSE` rather than `NA`, a warning, or an error.
#'
#' Matching runs only over the valid subset, which keeps ill-formed bytes away
#' from the regex engines entirely. That is what makes the two predicates
#' agree. Handed the same ill-formed bytes, R's engines answer differently ---
#' the default TRE engine matches bytewise and reports `TRUE`, while PCRE
#' (`perl = TRUE`) warns and reports `FALSE` --- and that divergence, not a
#' deliberate design choice, is why the predicates used to disagree.
#'
#' Both steps are load-bearing, and neither works alone. `enc2utf8()` is a
#' no-op on bytes already *marked* UTF-8, so it cannot detect ill-formed input;
#' `validUTF8()` inspects raw bytes, so on its own it would reject a perfectly
#' good string merely *marked* `latin1` (whose bytes are not UTF-8 but which R
#' transcodes before matching). Transcoding first and testing the result gets
#' both: `latin1` input is judged on what it means, UTF-8-marked garbage on
#' what it is. This also matches the boundary discipline of
#' `.call_with_validation()`, which likewise transcodes before dispatching.
#'
#' `NA_character_` is well-formed as far as `validUTF8()` is concerned, so it
#' reaches `grepl()` and yields `FALSE`, unchanged from previous releases.
#' @param x Character vector to test
#' @param pattern Regular expression passed to `grepl()`
#' @param ... Further arguments passed to `grepl()`, e.g. `perl` or
#'   `ignore.case`
#' @keywords internal
#' @noRd
.detect_valid_utf8 <- function(x, pattern, ...) {
  x <- enc2utf8(x)
  out <- logical(length(x))
  ok <- validUTF8(x)
  out[ok] <- grepl(pattern, x[ok], ...)
  out
}

#' Warn if input contains NA values
#' @param x Value to check
#' @keywords internal
#' @noRd
.warn_if_na <- function(x) {
  if (anyNA(x)) {
    warning("NA values detected in input", call. = FALSE)
  }
}

#' Validate inputs and dispatch to C++ function
#' @param x Character input
#' @param strict Logical flag
#' @param cpp_fn C++ function to call
#' @param x_arg Parameter name for error messages
#' @keywords internal
#' @noRd
.call_with_validation <- function(x, strict, cpp_fn, x_arg = "x") {
  .assert_character(x, x_arg)
  .assert_flag(strict, "strict")
  .warn_if_na(x)
  cpp_fn(enc2utf8(x), strict)
}

#' Wrap domain validation results with package classes and attributes
#' @keywords internal
#' @noRd
.new_validation_result <- function(result, strict) {
  structure(
    result,
    class = c("punycoder_validation", "list"),
    strict = strict
  )
}

# Internal backend metadata helper used by tests.
# @keywords internal
# @noRd
.backend_info <- function() {
  backend_info_cpp()
}

# Internal backend comparison helper used by tests.
# @keywords internal
# @noRd
.compare_backends <- function(x, mode, strict = TRUE) {
  .assert_character(x, "x")
  .assert_flag(strict, "strict")
  compare_backends_cpp(enc2utf8(x), mode, strict)
}

# Internal Unicode table-set helpers used by tests. Not API: the public surface
# pins one Unicode version, and per-call selection is a separate piece of work.
# @keywords internal
# @noRd
.unicode_versions <- function() {
  unicode_versions_cpp()
}

# @keywords internal
# @noRd
.host_normalize_version <- function(x, version, check_hyphens = TRUE,
                                    use_std3 = TRUE, verify_dns_length = TRUE) {
  .assert_character(x, "x")
  .assert_normalize_flags(check_hyphens, use_std3, verify_dns_length)
  out <- host_normalize_version_cpp(enc2utf8(x), version, check_hyphens,
                                    use_std3, verify_dns_length)
  names(out) <- names(x)
  out
}
