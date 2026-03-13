.assert_character <- function(x, arg = "Input") {
  if (!is.character(x)) {
    stop(arg, " must be a character vector", call. = FALSE)
  }
}

.assert_flag <- function(x, arg) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(arg, " must be TRUE or FALSE", call. = FALSE)
  }
}

.warn_if_na <- function(x) {
  if (anyNA(x)) {
    warning("NA values detected in input", call. = FALSE)
  }
}

.call_with_validation <- function(x, strict, cpp_fn, x_arg = "x") {
  .assert_character(x, x_arg)
  .assert_flag(strict, "strict")
  .warn_if_na(x)
  cpp_fn(x, strict)
}
