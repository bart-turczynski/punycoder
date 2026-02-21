#' @title Unicode and Punycode Domain Name Processing
#' @description
#' Provides high-performance functions for encoding and decoding
#' internationalized domain names according to RFC 3492 (Punycode)
#' and IDNA standards.
#'
#' @details
#' The punycoder package fills a critical gap in R's ecosystem for
#' handling international domain names. It provides reliable, fast
#' conversion between Unicode and ASCII representations of domain names.
#'
#' @name punycoder-package
#' @useDynLib punycoder, .registration = TRUE
#' @importFrom Rcpp sourceCpp
"_PACKAGE"

#' Encode Unicode domains to ASCII punycode
#'
#' Converts Unicode domain names to their ASCII punycode representation
#' following RFC 3492 standards. This function is essential for processing
#' internationalized domain names (IDNs) in web scraping and URL analysis.
#'
#' @param x Character vector of Unicode domain names to encode
#' @param strict Logical; whether to apply strict validation (default: TRUE)
#' @return Character vector of ASCII-encoded domains
#' @examples
#' \dontrun{
#' # Basic encoding
#' puny_encode("caf\\u00E9.com")
#' puny_encode("\\u043C\\u043E\\u0441\\u043A\\u0432\\u0430.\\u0440\\u0444")
#'
#' # Vectorized encoding
#' domains <- c(
#'   "caf\\u00E9.com",
#'   "\\u043C\\u043E\\u0441\\u043A\\u0432\\u0430.\\u0440\\u0444",
#'   "\\u5317\\u4EAC.\\u4E2D\\u56FD"
#' )
#' puny_encode(domains)
#' }
#' @export
puny_encode <- function(x, strict = TRUE) {
  .assert_character(x)
  .assert_flag(strict, "strict")
  .warn_if_na(x)

  puny_encode_cpp(x, strict)
}

#' Decode ASCII punycode to Unicode domains
#'
#' Converts ASCII punycode domain names back to their Unicode representation.
#' This is the reverse operation of puny_encode and is useful for displaying
#' human-readable domain names.
#'
#' @param x Character vector of ASCII punycode domains to decode
#' @param strict Logical; whether to apply strict validation (default: TRUE)
#' @return Character vector of Unicode-decoded domains
#' @examples
#' \dontrun{
#' # Basic decoding
#' puny_decode("xn--caf-dma.com")
#' puny_decode("xn--80adxhks.xn--p1ai")
#'
#' # Vectorized decoding
#' ascii_domains <- c("xn--caf-dma.com", "xn--80adxhks.xn--p1ai")
#' puny_decode(ascii_domains)
#' }
#' @export
puny_decode <- function(x, strict = TRUE) {
  .assert_character(x)
  .assert_flag(strict, "strict")
  .warn_if_na(x)

  puny_decode_cpp(x, strict)
}
