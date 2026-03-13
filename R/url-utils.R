#' Encode URLs with Unicode domains to ASCII
#'
#' Converts URLs containing Unicode domain names to their ASCII representation
#' while preserving the rest of the URL structure. This function is essential
#' for preparing URLs for systems that require ASCII-only domain names.
#'
#' @param url Character vector of URLs with potential Unicode domains
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

#' Decode URLs with ASCII punycode domains to Unicode
#'
#' Converts URLs containing ASCII punycode domain names back to their Unicode
#' representation for display purposes. This function makes internationalized
#' URLs human-readable.
#'
#' @param url Character vector of URLs with ASCII punycode domains
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

#' Parse URLs with internationalized domain name handling
#'
#' Parses URLs and returns a structured list with proper handling of
#' internationalized domain names. This function provides both Unicode
#' and ASCII representations of domain components.
#'
#' @param url Character vector of URLs to parse
#' @param encode_domains Logical flag; encode Unicode domains to ASCII.
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
#'   Each component has one element per input URL. Missing components are
#'   \code{NA}.
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

  result <- parse_url_cpp(url, encode_domains)

  structure(result,
            class = c("punycoder_parsed_url", "list"),
            encode_domains = encode_domains)
}

#' Print method for punycoder parsed URL results
#'
#' @param x A punycoder_parsed_url object
#' @param ... Additional arguments (ignored)
#' @export
print.punycoder_parsed_url <- function(x, ...) {
  cat("Punycoder Parsed URL Results\n")
  cat("============================\n\n")

  n <- length(x$scheme)
  for (i in seq_len(n)) {
    cat("URL", i, ":\n")
    cat("  Scheme:  ", if (is.na(x$scheme[i])) "<NA>" else x$scheme[i], "\n")
    cat("  Domain:  ", if (is.na(x$domain[i])) "<NA>" else x$domain[i], "\n")
    if (!is.na(x$port[i])) cat("  Port:    ", x$port[i], "\n")
    cat("  Path:    ", if (is.na(x$path[i])) "<NA>" else x$path[i], "\n")
    if (!is.na(x$query[i])) cat("  Query:   ", x$query[i], "\n")
    if (!is.na(x$fragment[i])) cat("  Fragment:", x$fragment[i], "\n")
    cat("\n")
  }

  invisible(x)
}
