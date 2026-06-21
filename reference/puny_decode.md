# Decode ASCII Punycode to Unicode domain labels (low-level)

Converts ASCII Punycode (\`xn–\`) domain names back to their Unicode
representation. This is the inverse of \[puny_encode()\] and is the raw
RFC 3492 transform with A-label framing checks.

## Usage

``` r
puny_decode(x, strict = getOption("punycoder.strict", TRUE))
```

## Arguments

- x:

  Character vector of ASCII punycode domains to decode

- strict:

  Logical; whether to apply strict validation. Defaults to
  \`getOption("punycoder.strict", TRUE)\`.

## Value

A character vector the same length as `x`, with each element containing
the Unicode-decoded domain name. Elements corresponding to `NA` inputs
are `NA_character_`. In non-strict mode, domains that fail decoding are
also returned as `NA_character_`.

## Details

Like \[puny_encode()\], this is a \*\*low-level ASCII-Compatible
Encoding helper, not an IDNA normalization API\*\*: it does not apply
UTS \#46 mapping or NFC. For IDNA/UTS-46 host normalization, see
\[host_normalize()\].

## See also

[`puny_encode`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md)
for the reverse operation,
[`host_normalize`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
for IDNA/UTS-46 host normalization,
[`url_decode`](https://bart-turczynski.github.io/punycoder/reference/url_decode.md)
for full URL decoding.

## Examples

``` r
# \donttest{
# Basic decoding
puny_decode("xn--caf-dma.com")
#> [1] "café.com"
puny_decode("xn--80adxhks.xn--p1ai")
#> [1] "москва.рф"

# Vectorized decoding
ascii_domains <- c("xn--caf-dma.com", "xn--80adxhks.xn--p1ai")
puny_decode(ascii_domains)
#> [1] "café.com"  "москва.рф"
# }
```
