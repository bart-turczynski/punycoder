#' Test if string is punycode encoded
#'
#' Determines whether a given string or domain name is already encoded
#' in punycode format (starts with xn-- prefix).
#'
#' @param x Character vector to test
#' @return A logical vector the same length as \code{x}, where \code{TRUE}
#'   indicates the element contains a punycode-encoded label (xn-- prefix).
#'   Never \code{NA} and never an error: an element that is not well-formed
#'   UTF-8 is reported as \code{FALSE}, matching \code{\link{is_idn}} and
#'   base R's own \code{\link{validUTF8}}. Use \code{validUTF8(x)} to tell
#'   "not punycode" apart from "not well-formed text".
#' @seealso \code{\link{is_idn}} for detecting Unicode domains,
#'   \code{\link{puny_decode}} for decoding punycode domains.
#' @examples
#' is_punycode("xn--example") # TRUE
#' is_punycode("example.com") # FALSE
#' is_punycode(c("xn--caf-dma.com", "regular.com")) # c(TRUE, FALSE)
#' @export
is_punycode <- function(x) {
  .assert_character(x)

  # Deliberately NOT `perl = TRUE`, unlike `is_idn()` below: PCRE adds no
  # matching capability a fixed "xn--" marker needs. The engines used to
  # disagree on ill-formed UTF-8 -- on "xn--a" followed by an encoded UTF-16
  # surrogate (ED A0 80) the default engine matched bytewise and returned TRUE
  # while PCRE warned and returned FALSE -- but `.detect_valid_utf8()` now
  # settles that before either engine runs, so the choice is free.
  .detect_valid_utf8(x, "(^|\\.)xn--", ignore.case = TRUE)
}

#' Test if domain contains internationalized characters
#'
#' Determines whether a domain name contains Unicode characters that
#' would require punycode encoding for ASCII compatibility.
#'
#' @param x Character vector of domain names to test
#' @return A logical vector the same length as \code{x}, where \code{TRUE}
#'   indicates the element contains non-ASCII Unicode characters. Never
#'   \code{NA} and never an error: an element that is not well-formed UTF-8 is
#'   reported as \code{FALSE}, matching \code{\link{is_punycode}} and base R's
#'   own \code{\link{validUTF8}}. Use \code{validUTF8(x)} to tell "not
#'   internationalized" apart from "not well-formed text".
#' @seealso \code{\link{is_punycode}} for detecting punycode domains,
#'   \code{\link{puny_encode}} for encoding Unicode domains.
#' @examples
#' is_idn("caf\u00E9.com") # TRUE
#' is_idn("example.com") # FALSE
#' is_idn(c(
#'   "caf\u00E9.com",
#'   "\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444",
#'   "test.com"
#' )) # c(TRUE, TRUE, FALSE)
#' @export
is_idn <- function(x) {
  .assert_character(x)

  # Portable non-ASCII check across regex engines. `.detect_valid_utf8()`
  # keeps ill-formed bytes away from PCRE, so the "invalid UTF-8" warning this
  # call used to emit is now structurally impossible rather than suppressed.
  .detect_valid_utf8(x, "[^\\x00-\\x7F]", perl = TRUE)
}

#' Comprehensive domain name validation
#'
#' Validates domain names according to RFC standards, checking for
#' proper format, length restrictions, and character requirements.
#' Supports both Unicode and ASCII domain names.
#'
#' @param x Character vector of domain names to validate
#' @param strict Logical; whether to apply strict validation. Defaults to
#'   `getOption("punycoder.strict", TRUE)`.
#' @return An object of class \code{"punycoder_validation"} (a named list)
#'   with components:
#'   \describe{
#'     \item{domains}{Character vector of the input domain names.}
#'     \item{valid}{Logical vector indicating whether each domain is valid.}
#'     \item{errors}{List of character vectors, each containing error messages
#'       for the corresponding domain (empty for valid domains).}
#'     \item{error_codes}{List of character vectors, each containing stable
#'       machine-readable error codes for the corresponding domain (empty for
#'       valid domains). Missing input uses \code{"domain_na"}.}
#'   }
#' @seealso \code{\link{puny_encode}} for encoding validated domains.
#' @examples
#' validate_domain("example.com")
#' validate_domain("caf\u00E9.example.com")
#' long_label <- paste(rep("x", 250), collapse = "")
#' validate_domain(c("valid.com", "invalid..com", long_label))
#' @export
validate_domain <- function(x, strict = getOption("punycoder.strict", TRUE)) {
  .assert_character(x)
  .assert_flag(strict, "strict")

  .new_validation_result(validate_domain_cpp(enc2utf8(x), strict), strict)
}
