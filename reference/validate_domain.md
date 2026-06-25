# Comprehensive domain name validation

Validates domain names according to RFC standards, checking for proper
format, length restrictions, and character requirements. Supports both
Unicode and ASCII domain names.

## Usage

``` r
validate_domain(x, strict = getOption("punycoder.strict", TRUE))
```

## Arguments

- x:

  Character vector of domain names to validate

- strict:

  Logical; whether to apply strict validation. Defaults to
  \`getOption("punycoder.strict", TRUE)\`.

## Value

An object of class `"punycoder_validation"` (a named list) with
components:

- domains:

  Character vector of the input domain names.

- valid:

  Logical vector indicating whether each domain is valid.

- errors:

  List of character vectors, each containing error messages for the
  corresponding domain (empty for valid domains).

- error_codes:

  List of character vectors, each containing stable machine-readable
  error codes for the corresponding domain (empty for valid domains).
  Missing input uses `"domain_na"`.

## See also

[`puny_encode`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md)
for encoding validated domains.

## Examples

``` r
# \donttest{
validate_domain("example.com")
#> Punycoder Domain Validation Results
#> ==================================
#> 
#> Domain: example.com 
#> Valid:  TRUE 
#> 
validate_domain("caf\u00E9.example.com")
#> Punycoder Domain Validation Results
#> ==================================
#> 
#> Domain: café.example.com 
#> Valid:  TRUE 
#> 
long_label <- paste(rep("x", 250), collapse = "")
validate_domain(c("valid.com", "invalid..com", long_label))
#> Punycoder Domain Validation Results
#> ==================================
#> 
#> Domain: valid.com 
#> Valid:  TRUE 
#> 
#> Domain: invalid..com 
#> Valid:  FALSE 
#> Errors:
#>   - Domain contains empty label 
#> 
#> Domain: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx 
#> Valid:  FALSE 
#> Errors:
#>   - Domain label too long (max 63 characters) 
#> 
# }
```
