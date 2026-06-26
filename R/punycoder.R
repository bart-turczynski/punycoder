#' Encode Unicode domain labels to ASCII Punycode (low-level)
#'
#' Converts Unicode domain names to their ASCII Punycode (`xn--`)
#' representation: the raw RFC 3492 Bootstring transform wrapped in the RFC
#' 5890/5891 A-label framing, plus letter-digit-hyphen and leading/trailing
#' hyphen checks per label. DNS host length limits are intentionally not
#' applied by this raw codec; use [validate_domain()] or [host_normalize()]
#' when you need DNS host validation.
#'
#' This is a **low-level ASCII-Compatible Encoding helper, not an IDNA
#' normalization API.** It does *not* apply Unicode NFC, UTS #46 mapping,
#' case folding, or Bidi/Joiner validation. To map a host name to its
#' canonical comparison form under a UTS #46 profile (the IDNA surface of this
#' package), use [host_normalize()].
#'
#' @param x Character vector of Unicode domain names to encode
#' @param strict Logical; whether to apply strict validation. Defaults to
#'   `getOption("punycoder.strict", TRUE)`. In strict mode the raw codec
#'   enforces structural checks but not DNS host length limits.
#' @return A character vector the same length as \code{x}, with each element
#'   containing the ASCII punycode-encoded domain name. Elements corresponding
#'   to \code{NA} inputs are \code{NA_character_}. In non-strict mode, domains
#'   that fail encoding are also returned as \code{NA_character_}.
#' @seealso \code{\link{puny_decode}} for the reverse operation,
#'   \code{\link{host_normalize}} for IDNA/UTS-46 host normalization,
#'   \code{\link{url_encode}} for full URL encoding.
#' @examples
#' \donttest{
#' # Basic encoding
#' puny_encode("caf\u00E9.com")
#' puny_encode("\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444")
#'
#' # Vectorized encoding
#' domains <- c(
#'   "caf\u00E9.com",
#'   "\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444",
#'   "\u5317\u4EAC.\u4E2D\u56FD"
#' )
#' puny_encode(domains)
#' }
#' @export
puny_encode <- function(x, strict = getOption("punycoder.strict", TRUE)) {
  .call_with_validation(x, strict, puny_encode_cpp)
}

#' Decode ASCII Punycode to Unicode domain labels (low-level)
#'
#' Converts ASCII Punycode (`xn--`) domain names back to their Unicode
#' representation. This is the inverse of [puny_encode()] and is the raw RFC
#' 3492 transform with A-label framing checks. DNS host length limits are
#' intentionally not applied by this raw codec; use [validate_domain()] or
#' [host_normalize()] when you need DNS host validation.
#'
#' Like [puny_encode()], this is a **low-level ASCII-Compatible Encoding
#' helper, not an IDNA normalization API**: it does not apply UTS #46 mapping
#' or NFC. For IDNA/UTS-46 host normalization, see [host_normalize()].
#'
#' @param x Character vector of ASCII punycode domains to decode
#' @param strict Logical; whether to apply strict validation. Defaults to
#'   `getOption("punycoder.strict", TRUE)`. In strict mode the raw codec
#'   enforces structural checks but not DNS host length limits.
#' @return A character vector the same length as \code{x}, with each element
#'   containing the Unicode-decoded domain name. Elements corresponding to
#'   \code{NA} inputs are \code{NA_character_}. In non-strict mode, domains
#'   that fail decoding are also returned as \code{NA_character_}.
#' @seealso \code{\link{puny_encode}} for the reverse operation,
#'   \code{\link{host_normalize}} for IDNA/UTS-46 host normalization,
#'   \code{\link{url_decode}} for full URL decoding.
#' @examples
#' \donttest{
#' # Basic decoding
#' puny_decode("xn--caf-dma.com")
#' puny_decode("xn--80adxhks.xn--p1ai")
#'
#' # Vectorized decoding
#' ascii_domains <- c("xn--caf-dma.com", "xn--80adxhks.xn--p1ai")
#' puny_decode(ascii_domains)
#' }
#' @export
puny_decode <- function(x, strict = getOption("punycoder.strict", TRUE)) {
  .call_with_validation(x, strict, puny_decode_cpp)
}
