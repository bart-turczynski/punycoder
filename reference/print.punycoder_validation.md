# Print method for punycoder validation results

Print method for punycoder validation results

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

## Examples

``` r
result <- validate_domain(c("example.com", "xn--bad-label-"))
print(result)
#> Punycoder Domain Validation Results
#> ==================================
#> 
#> Domain: example.com 
#> Valid:  TRUE 
#> 
#> Domain: xn--bad-label- 
#> Valid:  FALSE 
#> Errors:
#>   - Domain label cannot start or end with hyphen 
#> 
```
