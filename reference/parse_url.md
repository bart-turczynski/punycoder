# Best-effort host extraction from a URL-shaped string

Splits a URL-shaped string into coarse components with a hand-rolled
splitter, primarily to extract the host for
internationalized-domain-name handling, optionally ASCII-encoding it.

## Usage

``` r
parse_url(url, encode_domains = FALSE)
```

## Arguments

- url:

  Character vector of URL-shaped strings to split

- encode_domains:

  Logical flag; encode parsed host names to ASCII.

## Value

An object of class `"punycoder_parsed_url"` (a named list) with
components:

- scheme:

  Character vector of URL schemes (e.g., `"https"`).

- domain:

  Character vector of domain names.

- port:

  Integer vector of port numbers.

- path:

  Character vector of URL paths.

- query:

  Character vector of query strings.

- fragment:

  Character vector of fragment identifiers.

Each component has one element per input URL. Invalid URLs yield `NA`
components. For valid URLs without an explicit path, `path` is returned
as `""`.

## Details

This is **best-effort host extraction, not a conformant URL parser.** It
is *not* RFC 3986 / WHATWG URL compliant: there is no percent
encoding/decoding, no scheme validation, no robust port/path/query
semantics, no full IPv6 (zone IDs / RFC 6874 are unhandled), and no
serialization guarantees. The non-host components are returned as a
convenience only; for real URL parsing and canonicalization use a
dedicated URL package (e.g. `rurl`). This surface is slated for eventual
removal in favor of `rurl` consuming punycoder's host functions.

## Deprecated

This function is deprecated and slated for removal in a future release.
For URL parsing and canonicalization use a dedicated URL package (e.g.
`rurl`); for host-only encoding pass the host alone to
[`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
or
[`puny_encode()`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md).

## See also

[`url_encode`](https://bart-turczynski.github.io/punycoder/reference/url_encode.md),
[`url_decode`](https://bart-turczynski.github.io/punycoder/reference/url_decode.md)
for URL transformation with IDN handling.

## Examples

``` r
# \donttest{
# Parse URL with Unicode domain
parse_url(
  "https://caf\u00E9.example.com:8080/path?query=value#fragment"
)
#> Warning: 'parse_url()' is deprecated and will be removed in a future release.
#> Use the 'rurl' package for URL parsing/canonicalization, or host_normalize() / puny_encode() for host-only encoding.
#> Punycoder Parsed URL Results
#> ============================
#> 
#> URL 1 :
#>   Scheme:   https 
#>   Domain:   café.example.com 
#>   Port:     8080 
#>   Path:     /path 
#>   Query:    query=value 
#>   Fragment: fragment 
#> 

# Parse multiple URLs
urls <- c(
  "https://caf\u00E9.com/menu",
  "https://\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444/info"
)
parse_url(urls)
#> Warning: 'parse_url()' is deprecated and will be removed in a future release.
#> Use the 'rurl' package for URL parsing/canonicalization, or host_normalize() / puny_encode() for host-only encoding.
#> Punycoder Parsed URL Results
#> ============================
#> 
#> URL 1 :
#>   Scheme:   https 
#>   Domain:   café.com 
#>   Path:     /menu 
#> 
#> URL 2 :
#>   Scheme:   https 
#>   Domain:   москва.рф 
#>   Path:     /info 
#> 
# }
```
