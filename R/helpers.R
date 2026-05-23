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
  cpp_fn(x, strict)
}

#' Wrap parsed URL results with package classes and attributes
#' @keywords internal
#' @noRd
.new_parsed_url <- function(result, encode_domains) {
  structure(
    result,
    class = c("punycoder_parsed_url", "list"),
    encode_domains = encode_domains
  )
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
  compare_backends_cpp(x, mode, strict)
}
