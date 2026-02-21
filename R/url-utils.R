#' Encode URLs with Unicode domains to ASCII
#'
#' Converts URLs containing Unicode domain names to their ASCII representation
#' while preserving the rest of the URL structure. This function is essential
#' for preparing URLs for systems that require ASCII-only domain names.
#'
#' @param url Character vector of URLs with potential Unicode domains
#' @param strict Logical; whether to apply strict validation. Defaults to
#'   `getOption("punycoder.strict", TRUE)`.
#' @return Character vector of URLs with ASCII-encoded domains
#' @examples
#' \dontrun{
#' # Basic URL encoding
#' url_encode("https://caf\\u00E9.example.com/path?query=value")
#' url_encode(
#'   "https://\\u043C\\u043E\\u0441\\u043A\\u0432\\u0430.\\u0440\\u0444/page"
#' )
#'
#' # Vectorized URL encoding
#' urls <- c(
#'   "https://caf\\u00E9.com/menu",
#'   "https://\\u5317\\u4EAC.\\u4E2D\\u56FD/info"
#' )
#' url_encode(urls)
#' }
#' @export
url_encode <- function(url, strict = getOption("punycoder.strict", TRUE)) {
  .assert_character(url)
  .assert_flag(strict, "strict")
  .warn_if_na(url)

  url_encode_cpp(url, strict)
}

#' Decode URLs with ASCII punycode domains to Unicode
#'
#' Converts URLs containing ASCII punycode domain names back to their Unicode
#' representation for display purposes. This function makes internationalized
#' URLs human-readable.
#'
#' @param url Character vector of URLs with ASCII punycode domains
#' @param strict Logical; whether to apply strict validation. Defaults to
#'   `getOption("punycoder.strict", TRUE)`.
#' @return Character vector of URLs with Unicode-decoded domains
#' @examples
#' \dontrun{
#' # Basic URL decoding
#' url_decode("https://xn--caf-dma.example.com/path")
#' url_decode("https://xn--80adxhks.xn--p1ai/page")
#'
#' # Vectorized URL decoding
#' ascii_urls <- c(
#'   "https://xn--caf-dma.com/menu",
#'   "https://xn--1qqw23a.xn--55qx5d/info"
#' )
#' url_decode(ascii_urls)
#' }
#' @export
url_decode <- function(url, strict = getOption("punycoder.strict", TRUE)) {
  .assert_character(url)
  .assert_flag(strict, "strict")
  .warn_if_na(url)

  url_decode_cpp(url, strict)
}

#' Parse URLs with internationalized domain name handling
#'
#' Parses URLs and returns a structured list with proper handling of
#' internationalized domain names. This function provides both Unicode
#' and ASCII representations of domain components.
#'
#' @param url Character vector of URLs to parse
#' @param encode_domains Logical flag; encode Unicode domains to ASCII.
#' @return List containing URL components with IDN handling
#' @examples
#' \dontrun{
#' # Parse URL with Unicode domain
#' parse_url(
#'   "https://caf\\u00E9.example.com:8080/path?query=value#fragment"
#' )
#'
#' # Parse multiple URLs
#' urls <- c(
#'   "https://caf\\u00E9.com/menu",
#'   "https://\\u043C\\u043E\\u0441\\u043A\\u0432\\u0430.\\u0440\\u0444/info"
#' )
#' parse_url(urls)
#' }
#' @export
parse_url <- function(url, encode_domains = FALSE) {
  .assert_character(url)
  .assert_flag(encode_domains, "encode_domains")
  .warn_if_na(url)

  result <- parse_url_cpp(url, encode_domains)

  structure(result,
            class = c("punycoder_parsed_url", "list"),
            encode_domains = encode_domains)
}
