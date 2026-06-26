# Print method for punycoder parsed URL results

Print method for punycoder parsed URL results

## Usage

``` r
# S3 method for class 'punycoder_parsed_url'
print(x, ...)
```

## Arguments

- x:

  A punycoder_parsed_url object

- ...:

  Additional arguments (ignored)

## Value

Invisibly returns `x`.

## Examples

``` r
# \donttest{
parsed <- parse_url("https://caf\u00E9.example.com/path")
#> Warning: 'parse_url()' is deprecated and will be removed in a future release.
#> Use the 'rurl' package for URL parsing/canonicalization, or host_normalize() / puny_encode() for host-only encoding.
print(parsed)
#> Punycoder Parsed URL Results
#> ============================
#> 
#> URL 1 :
#>   Scheme:   https 
#>   Domain:   café.example.com 
#>   Path:     /path 
#> 
# }
```
