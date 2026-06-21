# Canonical-host normalization profile identity

Returns the stable, machine-readable identity of a normalization
profile. Called with no arguments it reports the default (fully strict)
profile \[host_normalize()\] applies; the \`check_hyphens\`,
\`use_std3\`, and \`verify_dns_length\` arguments report the identity of
a specific flag set so a caller can describe the exact profile a given
normalization used. Downstream packages key reproducibility on the full
per-parameter column set; \`profile\` is a coarse cache token (distinct
per flag set, but no longer load-bearing alone) and the \`backend\`
column is diagnostic only and must never enter a reproducibility or
cache key.

## Usage

``` r
normalization_profile_info(
  check_hyphens = TRUE,
  use_std3 = TRUE,
  verify_dns_length = TRUE
)
```

## Arguments

- check_hyphens, use_std3, verify_dns_length:

  Logical scalars selecting the flag set to report. Each defaults to
  \`TRUE\` (the strict profile).

## Value

A one-row \`data.frame\` with columns \`profile\`, \`unicode_version\`,
\`idna\`, \`transitional\`, \`use_std3\`, \`check_hyphens\`,
\`check_bidi\`, \`check_joiners\`, \`verify_dns_length\`, and
\`backend\`.

## Details

\`check_bidi\`, \`check_joiners\`, and \`transitional\` are fixed by the
profile (UTS \#46 non-transitional, both bidi and joiner checks always
on) and are reported as constant columns rather than arguments.

## See also

\[host_normalize()\].

## Examples

``` r
normalization_profile_info()
#>                         profile unicode_version  idna transitional use_std3
#> 1 uts46-nontransitional-std3-v1          16.0.0 uts46        FALSE     TRUE
#>   check_hyphens check_bidi check_joiners verify_dns_length  backend
#> 1          TRUE       TRUE          TRUE              TRUE fallback
normalization_profile_info(use_std3 = FALSE)
#>                                 profile unicode_version  idna transitional
#> 1 uts46-nontransitional-std3-v1+no-std3          16.0.0 uts46        FALSE
#>   use_std3 check_hyphens check_bidi check_joiners verify_dns_length  backend
#> 1    FALSE          TRUE       TRUE          TRUE              TRUE fallback
```
