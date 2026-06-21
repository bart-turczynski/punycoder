# Test if string is punycode encoded

Determines whether a given string or domain name is already encoded in
punycode format (starts with xn– prefix).

## Usage

``` r
is_punycode(x)
```

## Arguments

- x:

  Character vector to test

## Value

A logical vector the same length as `x`, where `TRUE` indicates the
element contains a punycode-encoded label (xn– prefix).

## See also

[`is_idn`](https://bart-turczynski.github.io/punycoder/reference/is_idn.md)
for detecting Unicode domains,
[`puny_decode`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md)
for decoding punycode domains.

## Examples

``` r
# \donttest{
is_punycode("xn--example") # TRUE
#> [1] TRUE
is_punycode("example.com") # FALSE
#> [1] FALSE
is_punycode(c("xn--caf-dma.com", "regular.com")) # c(TRUE, FALSE)
#> [1]  TRUE FALSE
# }
```
