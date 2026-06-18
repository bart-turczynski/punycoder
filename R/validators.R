#' Test if string is punycode encoded
#'
#' Determines whether a given string or domain name is already encoded
#' in punycode format (starts with xn-- prefix).
#'
#' @param x Character vector to test
#' @return A logical vector the same length as \code{x}, where \code{TRUE}
#'   indicates the element contains a punycode-encoded label (xn-- prefix).
#' @seealso \code{\link{is_idn}} for detecting Unicode domains,
#'   \code{\link{puny_decode}} for decoding punycode domains.
#' @examples
#' \donttest{
#' is_punycode("xn--example") # TRUE
#' is_punycode("example.com") # FALSE
#' is_punycode(c("xn--caf-dma.com", "regular.com")) # c(TRUE, FALSE)
#' }
#' @export
is_punycode <- function(x) {
  .assert_character(x)

  grepl("(^|\\.)(xn--)", x, ignore.case = TRUE)
}

#' Test if domain contains internationalized characters
#'
#' Determines whether a domain name contains Unicode characters that
#' would require punycode encoding for ASCII compatibility.
#'
#' @param x Character vector of domain names to test
#' @return A logical vector the same length as \code{x}, where \code{TRUE}
#'   indicates the element contains non-ASCII Unicode characters.
#' @seealso \code{\link{is_punycode}} for detecting punycode domains,
#'   \code{\link{puny_encode}} for encoding Unicode domains.
#' @examples
#' \donttest{
#' is_idn("caf\u00E9.com") # TRUE
#' is_idn("example.com") # FALSE
#' is_idn(c(
#'   "caf\u00E9.com",
#'   "\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444",
#'   "test.com"
#' )) # c(TRUE, TRUE, FALSE)
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
#' \donttest{
#' validate_domain("example.com")
#' validate_domain("caf\u00E9.example.com")
#' long_label <- paste(rep("x", 250), collapse = "")
#' validate_domain(c("valid.com", "invalid..com", long_label))
#' }
#' @export
validate_domain <- function(x, strict = getOption("punycoder.strict", TRUE)) {
  .assert_character(x)
  .assert_flag(strict, "strict")

  .new_validation_result(validate_domain_cpp(x, strict), strict)
}
