# Test if domain contains internationalized characters

Determines whether a domain name contains Unicode characters that would
require punycode encoding for ASCII compatibility.

## Usage

``` r
is_idn(x)
```

## Arguments

- x:

  Character vector of domain names to test

## Value

A logical vector the same length as `x`, where `TRUE` indicates the
element contains non-ASCII Unicode characters.

## See also

[`is_punycode`](https://bart-turczynski.github.io/punycoder/reference/is_punycode.md)
for detecting punycode domains,
[`puny_encode`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md)
for encoding Unicode domains.

## Examples

``` r
# \donttest{
is_idn("caf\u00E9.com") # TRUE
#> [1] TRUE
is_idn("example.com") # FALSE
#> [1] FALSE
is_idn(c(
  "caf\u00E9.com",
  "\u043C\u043E\u0441\u043A\u0432\u0430.\u0440\u0444",
  "test.com"
)) # c(TRUE, TRUE, FALSE)
#> [1]  TRUE  TRUE FALSE
# }
```
