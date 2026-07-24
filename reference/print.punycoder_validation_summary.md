# Print method for punycoder validation summaries

Print method for punycoder validation summaries

## Usage

``` r
# S3 method for class 'punycoder_validation_summary'
print(x, ...)
```

## Arguments

- x:

  A punycoder_validation_summary object, as returned by
  [`summary.punycoder_validation`](https://bart-turczynski.github.io/punycoder/reference/summary.punycoder_validation.md)

- ...:

  Additional arguments (ignored)

## Value

Invisibly returns `x`.

## Examples

``` r
print(summary(validate_domain(c("example.com", "-bad.com"))))
#> Punycoder validation summary (strict = TRUE)
#> 2 domains: 1 valid, 1 invalid
#> 
#>  error_code          n
#>  domain_label_hyphen 1
```
