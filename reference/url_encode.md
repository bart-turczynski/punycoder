# Best-effort host rewriting in a URL-shaped string (Unicode host to ASCII)

Locates the host portion of a URL-shaped string with a hand-rolled
splitter, ASCII-encodes that host, and substitutes it back, leaving the
rest of the string untouched.

## Usage

``` r
url_encode(url, strict = getOption("punycoder.strict", TRUE))
```

## Arguments

- url:

  Character vector of URL-shaped strings with potential Unicode hosts

- strict:

  Logical; whether to apply strict validation. Defaults to
  \`getOption("punycoder.strict", TRUE)\`.

## Value

A character vector the same length as `url`, with each element
containing the URL with its host portion ASCII-encoded. Only the domain
component is transformed; scheme, path, query, and fragment are
preserved. Elements corresponding to `NA` inputs are `NA_character_`.

## Details

This is \*\*best-effort host extraction and rewriting, not URL parsing
or canonicalization.\*\* It is deliberately \*not\* RFC 3986 / WHATWG
URL conformant. Non-goals (handled upstack, e.g. by \`rurl\`): percent
encoding/decoding, scheme validation, port/path/query semantics, full
IPv6 (including zone IDs / RFC 6874), and URL serialization. Pass only
the host to \[host_normalize()\] / \[puny_encode()\] when you control
the parse; use this helper only for quick host rewriting in an
already-trusted URL-shaped string.

## Deprecated

This function is deprecated and slated for removal in a future release.
For URL parsing and canonicalization use a dedicated URL package (e.g.
\`rurl\`); for host-only encoding pass the host alone to
\[host_normalize()\] or \[puny_encode()\].

## See also

[`url_decode`](https://bart-turczynski.github.io/punycoder/reference/url_decode.md)
for the reverse operation,
[`puny_encode`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md)
for domain-only encoding,
[`parse_url`](https://bart-turczynski.github.io/punycoder/reference/parse_url.md)
for URL component extraction.

## Examples

``` r
# \donttest{
# Basic URL encoding
url_encode("https://caf\u00E9.example.com/path?query=value")
#> Warning: 'url_encode()' is deprecated and will be removed in a future release.
#> Use the 'rurl' package for URL parsing/canonicalization, or host_normalize() / puny_encode() for host-only encoding.
#> [1] "https://xn--caf-dma.example.com/path?query=value"
url_encode(
  "https://\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444/page"
)
#> Warning: 'url_encode()' is deprecated and will be removed in a future release.
#> Use the 'rurl' package for URL parsing/canonicalization, or host_normalize() / puny_encode() for host-only encoding.
#> [1] "https://xn--80adxhks.xn--p1ai/page"

# Vectorized URL encoding
urls <- c(
  "https://caf\u00E9.com/menu",
  "https://\u5317\u4EAC.\u4E2D\u56FD/info"
)
url_encode(urls)
#> Warning: 'url_encode()' is deprecated and will be removed in a future release.
#> Use the 'rurl' package for URL parsing/canonicalization, or host_normalize() / puny_encode() for host-only encoding.
#> [1] "https://xn--caf-dma.com/menu"       "https://xn--1lq90i.xn--fiqs8s/info"
# }
```
