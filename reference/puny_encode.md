# Encode Unicode domain labels to ASCII Punycode (low-level)

Converts Unicode domain names to their ASCII Punycode (\`xn–\`)
representation: the raw RFC 3492 Bootstring transform wrapped in the RFC
5890/5891 A-label framing, plus letter-digit-hyphen and length/hyphen
checks per label.

## Usage

``` r
puny_encode(x, strict = getOption("punycoder.strict", TRUE))
```

## Arguments

- x:

  Character vector of Unicode domain names to encode

- strict:

  Logical; whether to apply strict validation. Defaults to
  \`getOption("punycoder.strict", TRUE)\`.

## Value

A character vector the same length as `x`, with each element containing
the ASCII punycode-encoded domain name. Elements corresponding to `NA`
inputs are `NA_character_`. In non-strict mode, domains that fail
encoding are also returned as `NA_character_`.

## Details

This is a \*\*low-level ASCII-Compatible Encoding helper, not an IDNA
normalization API.\*\* It does \*not\* apply Unicode NFC, UTS \#46
mapping, case folding, or Bidi/Joiner validation. To map a host name to
its canonical comparison form under a UTS \#46 profile (the IDNA surface
of this package), use \[host_normalize()\].

## See also

[`puny_decode`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md)
for the reverse operation,
[`host_normalize`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
for IDNA/UTS-46 host normalization,
[`url_encode`](https://bart-turczynski.github.io/punycoder/reference/url_encode.md)
for full URL encoding.

## Examples

``` r
# \donttest{
# Basic encoding
puny_encode("caf\u00E9.com")
#> [1] "xn--caf-dma.com"
puny_encode("\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444")
#> [1] "xn--80adxhks.xn--p1ai"

# Vectorized encoding
domains <- c(
  "caf\u00E9.com",
  "\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444",
  "\u5317\u4EAC.\u4E2D\u56FD"
)
puny_encode(domains)
#> [1] "xn--caf-dma.com"       "xn--80adxhks.xn--p1ai" "xn--1lq90i.xn--fiqs8s"
# }
```
