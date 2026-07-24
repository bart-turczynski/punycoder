# Summarize punycoder validation results

Condenses a `punycoder_validation` object into counts of failures by
machine-readable error code. The per-domain detail stays available on
the validation object itself (`$errors` / `$error_codes`) and in
[`print.punycoder_validation`](https://bart-turczynski.github.io/punycoder/reference/print.punycoder_validation.md).

## Usage

``` r
# S3 method for class 'punycoder_validation'
summary(object, ...)
```

## Arguments

- object:

  A punycoder_validation object

- ...:

  Additional arguments (ignored)

## Value

A data frame of class `"punycoder_validation_summary"` with one row per
distinct error code, sorted by count descending, and columns:

- error_code:

  Character; the stable machine-readable error code.

- n:

  Integer; how many domains reported that code.

Input with no errors yields a zero-row data frame with the same columns.
The result carries the attributes `n` (number of domains), `n_valid`,
`n_invalid`, and `strict`.

## See also

[`validate_domain`](https://bart-turczynski.github.io/punycoder/reference/validate_domain.md),
[`print.punycoder_validation`](https://bart-turczynski.github.io/punycoder/reference/print.punycoder_validation.md).

## Examples

``` r
result <- validate_domain(c("example.com", "-bad.com", "bad_label.com"))
summary(result)
#> Punycoder validation summary (strict = TRUE)
#> 3 domains: 1 valid, 2 invalid
#> 
#>  error_code              n
#>  ascii_domain_characters 1
#>  domain_label_hyphen     1
```
