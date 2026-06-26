# Best-effort host rewriting in a URL-shaped string (ASCII punycode to Unicode)

Locates the host portion of a URL-shaped string with a hand-rolled
splitter, decodes that host from ASCII punycode to Unicode, and
substitutes it back, leaving the rest of the string untouched.

## Usage

``` r
url_decode(url, strict = getOption("punycoder.strict", TRUE))
```

## Arguments

- url:

  Character vector of URL-shaped strings with ASCII punycode hosts

- strict:

  Logical; whether to apply strict validation. Defaults to
  `getOption("punycoder.strict", TRUE)`.

## Value

A character vector the same length as `url`, with each element
containing the URL with its host portion decoded to Unicode. Only the
domain component is transformed; scheme, path, query, and fragment are
preserved. Elements corresponding to `NA` inputs are `NA_character_`.

## Details

Like
[`url_encode()`](https://bart-turczynski.github.io/punycoder/reference/url_encode.md),
this is **best-effort host extraction and rewriting, not URL parsing or
canonicalization**, and is not RFC 3986 / WHATWG URL conformant (no
percent encoding/decoding, scheme/port/path semantics, full IPv6, or
serialization). Those concerns live upstack in `rurl`.

## Deprecated

This function is deprecated and slated for removal in a future release.
For URL parsing and canonicalization use a dedicated URL package (e.g.
`rurl`); for host-only decoding pass the host alone to
[`puny_decode()`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md).

## See also

[`url_encode`](https://bart-turczynski.github.io/punycoder/reference/url_encode.md)
for the reverse operation,
[`puny_decode`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md)
for domain-only decoding,
[`parse_url`](https://bart-turczynski.github.io/punycoder/reference/parse_url.md)
for URL component extraction.

## Examples

``` r
# \donttest{
# Basic URL decoding
url_decode("https://xn--caf-dma.example.com/path")
#> Warning: 'url_decode()' is deprecated and will be removed in a future release.
#> Use the 'rurl' package for URL parsing/canonicalization, or host_normalize() / puny_decode() for host-only decoding.
#> [1] "https://café.example.com/path"
url_decode("https://xn--80adxhks.xn--p1ai/page")
#> Warning: 'url_decode()' is deprecated and will be removed in a future release.
#> Use the 'rurl' package for URL parsing/canonicalization, or host_normalize() / puny_decode() for host-only decoding.
#> [1] "https://москва.рф/page"

# Vectorized URL decoding
ascii_urls <- c(
  "https://xn--caf-dma.com/menu",
  "https://xn--1qqw23a.xn--55qx5d/info"
)
url_decode(ascii_urls)
#> Warning: 'url_decode()' is deprecated and will be removed in a future release.
#> Use the 'rurl' package for URL parsing/canonicalization, or host_normalize() / puny_decode() for host-only decoding.
#> [1] "https://café.com/menu"  "https://佛山.公司/info"
# }
```
