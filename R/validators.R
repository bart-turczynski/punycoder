#' Test if string is punycode encoded
#'
#' Determines whether a given string or domain name is already encoded
#' in punycode format (starts with xn-- prefix).
#'
#' @param x Character vector to test
#' @return Logical vector indicating which elements are punycode
#' @examples
#' \dontrun{
#' is_punycode("xn--example") # TRUE
#' is_punycode("example.com") # FALSE
#' is_punycode(c("xn--caf-dma.com", "regular.com"))  # c(TRUE, FALSE)
#' }
#' @export
is_punycode <- function(x) {
  .assert_character(x)

  # Check for xn-- prefix (case insensitive)
  grepl("^xn--", x, ignore.case = TRUE) |
    grepl("\\.xn--", x, ignore.case = TRUE)
}

#' Test if domain contains internationalized characters
#'
#' Determines whether a domain name contains Unicode characters that
#' would require punycode encoding for ASCII compatibility.
#'
#' @param x Character vector of domain names to test
#' @return Logical vector indicating which domains contain Unicode characters
#' @examples
#' \dontrun{
#' is_idn("caf\\u00E9.com") # TRUE
#' is_idn("example.com")    # FALSE
#' is_idn(c(
#'   "caf\\u00E9.com",
#'   "\\u043C\\u043E\\u0441\\u043A\\u0432\\u0430.\\u0440\\u0444",
#'   "test.com"
#' ))  # c(TRUE, TRUE, FALSE)
#' }
#' @export
is_idn <- function(x) {
  .assert_character(x)

  # Portable non-ASCII check across regex engines.
  grepl("[^\\x00-\\x7F]", x, perl = TRUE)
}

#' Comprehensive domain name validation
#'
#' Validates domain names according to RFC standards, checking for
#' proper format, length restrictions, and character requirements.
#' Supports both Unicode and ASCII domain names.
#'
#' @param x Character vector of domain names to validate
#' @param strict Logical; whether to apply strict validation (default: TRUE)
#' @return List containing validation results and error messages
#' @examples
#' \dontrun{
#' validate_domain("example.com")
#' validate_domain("caf\\u00E9.example.com")
#' long_label <- paste(rep("x", 250), collapse = "")
#' validate_domain(c("valid.com", "invalid..com", long_label))
#' }
#' @export
validate_domain <- function(x, strict = TRUE) {
  .assert_character(x)
  .assert_flag(strict, "strict")

  result <- validate_domain_cpp(x, strict)

  structure(result,
            class = c("punycoder_validation", "list"),
            strict = strict)
}

#' Get domain validation summary
#'
#' Internal helper function to provide human-readable validation summaries.
#'
#' @param validation_result Result from validate_domain function
#' @return Character vector with validation summary
#' @keywords internal
get_validation_summary <- function(validation_result) {
  if (!inherits(validation_result, "punycoder_validation")) {
    stop("Input must be a punycoder_validation object", call. = FALSE)
  }

  vapply(
    validation_result$errors,
    FUN.VALUE = character(1),
    function(err) {
      if (length(err) == 0) {
        "Valid"
      } else {
        paste(err, collapse = "; ")
      }
    }
  )
}

#' Print method for punycoder validation results
#'
#' @param x A punycoder_validation object
#' @param ... Additional arguments (ignored)
#' @export
print.punycoder_validation <- function(x, ...) {
  cat("Punycoder Domain Validation Results\n")
  cat("==================================\n\n")

  for (i in seq_along(x$domains)) {
    cat("Domain:", x$domains[i], "\n")
    cat("Valid: ", x$valid[i], "\n")

    if (!x$valid[i] && length(x$errors[[i]]) > 0) {
      cat("Errors:\n")
      for (error in x$errors[[i]]) {
        cat("  -", error, "\n")
      }
    }
    cat("\n")
  }

  invisible(x)
}
