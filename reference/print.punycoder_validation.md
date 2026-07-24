# Print method for punycoder validation results

Prints a count header followed by one block per domain, truncated to the
first 10 elements. Error bullets carry the machine-readable error code
in brackets; use
[`summary()`](https://bart-turczynski.github.io/punycoder/reference/summary.punycoder_validation.md)
for counts by error code across the whole vector.

## Usage

``` r
# S3 method for class 'punycoder_validation'
print(x, ...)
```

## Arguments

- x:

  A punycoder_validation object

- ...:

  Additional arguments (ignored)

## Value

Invisibly returns `x`.

## See also

[`summary.punycoder_validation`](https://bart-turczynski.github.io/punycoder/reference/summary.punycoder_validation.md)
for the aggregate view.

## Examples

``` r
result <- validate_domain(c("example.com", "xn--bad-label-"))
print(result)
#> Punycoder Domain Validation Results
#> ==================================
#> 
#> 2 domains: 1 valid, 1 invalid (strict = TRUE)
#> 
#> Domain: example.com 
#> Valid:  TRUE 
#> 
#> Domain: xn--bad-label- 
#> Valid:  FALSE 
#> Errors:
#>   - Domain label cannot start or end with hyphen [domain_label_hyphen]
#> 
```
