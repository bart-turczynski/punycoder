#' Best-effort host rewriting in a URL-shaped string (Unicode host to ASCII)
#'
#' Locates the host portion of a URL-shaped string with a hand-rolled
#' splitter, ASCII-encodes that host, and substitutes it back, leaving the
#' rest of the string untouched.
#'
#' This is **best-effort host extraction and rewriting, not URL parsing or
#' canonicalization.** It is deliberately *not* RFC 3986 / WHATWG URL
#' conformant. Non-goals (handled upstack, e.g. by `rurl`): percent
#' encoding/decoding, scheme validation, port/path/query semantics, full
#' IPv6 (including zone IDs / RFC 6874), and URL serialization. Pass only the
#' host to [host_normalize()] / [puny_encode()] when you control the parse;
#' use this helper only for quick host rewriting in an already-trusted
#' URL-shaped string.
#'
#' @param url Character vector of URL-shaped strings with potential Unicode
#'   hosts
#' @param strict Logical; whether to apply strict validation. Defaults to
#'   `getOption("punycoder.strict", TRUE)`.
#' @return A character vector the same length as \code{url}, with each element
#'   containing the URL with its host portion ASCII-encoded. Only the domain
#'   component is transformed; scheme, path, query, and fragment are preserved.
#'   Elements corresponding to \code{NA} inputs are \code{NA_character_}.
#' @seealso \code{\link{url_decode}} for the reverse operation,
#'   \code{\link{puny_encode}} for domain-only encoding,
#'   \code{\link{parse_url}} for URL component extraction.
#' @examples
#' \donttest{
#' # Basic URL encoding
#' url_encode("https://caf\u00E9.example.com/path?query=value")
#' url_encode(
#'   "https://\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444/page"
#' )
#'
#' # Vectorized URL encoding
#' urls <- c(
#'   "https://caf\u00E9.com/menu",
#'   "https://\u5317\u4EAC.\u4E2D\u56FD/info"
#' )
#' url_encode(urls)
#' }
#' @export
url_encode <- function(url, strict = getOption("punycoder.strict", TRUE)) {
  .call_with_validation(url, strict, url_encode_cpp, "url")
}

#' Best-effort host rewriting in a URL-shaped string (ASCII punycode to Unicode)
#'
#' Locates the host portion of a URL-shaped string with a hand-rolled
#' splitter, decodes that host from ASCII punycode to Unicode, and
#' substitutes it back, leaving the rest of the string untouched.
#'
#' Like [url_encode()], this is **best-effort host extraction and rewriting,
#' not URL parsing or canonicalization**, and is not RFC 3986 / WHATWG URL
#' conformant (no percent encoding/decoding, scheme/port/path semantics, full
#' IPv6, or serialization). Those concerns live upstack in `rurl`.
#'
#' @param url Character vector of URL-shaped strings with ASCII punycode hosts
#' @param strict Logical; whether to apply strict validation. Defaults to
#'   `getOption("punycoder.strict", TRUE)`.
#' @return A character vector the same length as \code{url}, with each element
#'   containing the URL with its host portion decoded to Unicode. Only the
#'   domain component is transformed; scheme, path, query, and fragment are
#'   preserved. Elements corresponding to \code{NA} inputs are
#'   \code{NA_character_}.
#' @seealso \code{\link{url_encode}} for the reverse operation,
#'   \code{\link{puny_decode}} for domain-only decoding,
#'   \code{\link{parse_url}} for URL component extraction.
#' @examples
#' \donttest{
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
  .call_with_validation(url, strict, url_decode_cpp, "url")
}

#' Best-effort host extraction from a URL-shaped string
#'
#' Splits a URL-shaped string into coarse components with a hand-rolled
#' splitter, primarily to extract the host for internationalized-domain-name
#' handling, optionally ASCII-encoding it.
#'
#' This is **best-effort host extraction, not a conformant URL parser.** It is
#' *not* RFC 3986 / WHATWG URL compliant: there is no percent encoding/decoding,
#' no scheme validation, no robust port/path/query semantics, no full IPv6
#' (zone IDs / RFC 6874 are unhandled), and no serialization guarantees. The
#' non-host components are returned as a convenience only; for real URL parsing
#' and canonicalization use a dedicated URL package (e.g. `rurl`). This surface
#' is slated for eventual removal in favour of `rurl` consuming punycoder's host
#' functions.
#'
#' @param url Character vector of URL-shaped strings to split
#' @param encode_domains Logical flag; encode parsed host names to ASCII.
#' @return An object of class \code{"punycoder_parsed_url"} (a named list)
#'   with components:
#'   \describe{
#'     \item{scheme}{Character vector of URL schemes (e.g., \code{"https"}).}
#'     \item{domain}{Character vector of domain names.}
#'     \item{port}{Integer vector of port numbers.}
#'     \item{path}{Character vector of URL paths.}
#'     \item{query}{Character vector of query strings.}
#'     \item{fragment}{Character vector of fragment identifiers.}
#'   }
#'   Each component has one element per input URL. Invalid URLs yield
#'   \code{NA} components. For valid URLs without an explicit path,
#'   \code{path} is returned as \code{""}.
#' @seealso \code{\link{url_encode}}, \code{\link{url_decode}} for URL
#'   transformation with IDN handling.
#' @examples
#' \donttest{
#' # Parse URL with Unicode domain
#' parse_url(
#'   "https://caf\u00E9.example.com:8080/path?query=value#fragment"
#' )
#'
#' # Parse multiple URLs
#' urls <- c(
#'   "https://caf\u00E9.com/menu",
#'   "https://\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444/info"
#' )
#' parse_url(urls)
#' }
#' @export
parse_url <- function(url, encode_domains = FALSE) {
  .assert_character(url)
  .assert_flag(encode_domains, "encode_domains")
  .warn_if_na(url)

  .new_parsed_url(parse_url_cpp(url, encode_domains), encode_domains)
}
