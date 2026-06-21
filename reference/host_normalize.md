# Normalize hosts to canonical comparison form

Converts DNS hostnames to their canonical comparison form following the
ratified canonical-host normalization contract: Unicode NFC, case
mapping, UTS-46 label mapping and validation (non-transitional, with
\`UseSTD3ASCIIRules\`, \`CheckHyphens\`, \`CheckBidi\`, and
\`CheckJoiners\`), conversion to lowercase ASCII A-labels, and DNS
length verification, while preserving whether the input carried a single
terminal root dot.

## Usage

``` r
host_normalize(
  x,
  check_hyphens = TRUE,
  use_std3 = TRUE,
  verify_dns_length = TRUE
)
```

## Arguments

- x:

  Character vector of hostnames. \`NA\` elements pass through as \`NA\`
  (missing, not invalid). Names are preserved.

- check_hyphens:

  Logical scalar. When \`TRUE\` (the default) the UTS \#46
  \`CheckHyphens\` rule rejects \`"–"\` in the 3rd/4th positions and
  leading or trailing hyphens. \`FALSE\` drops that check.

- use_std3:

  Logical scalar. When \`TRUE\` (the default) \`UseSTD3ASCIIRules\`
  restricts ASCII to letters, digits, and hyphen. \`FALSE\` admits other
  ASCII (e.g. \`"\_"\`) that the pinned table marks
  STD3-disallowed-but-valid.

- verify_dns_length:

  Logical scalar. When \`TRUE\` (the default) each A-label must be 1-63
  octets and the whole host \<= 253. \`FALSE\` drops the length limits
  (empty labels are still rejected as structural errors).

## Value

A character vector the same length as \`x\`. Each element is the
canonical lowercase ASCII A-label host, or \`NA_character\_\` when the
input is \`NA\` or invalid under the profile.

## Details

Unlike \[puny_encode()\], invalid input is reported by returning
\`NA_character\_\` (never by aborting), so a caller can layer its own
policy. The profile is fixed at one pinned Unicode version per release;
see \[normalization_profile_info()\] for the machine-readable identity.

This is a \*\*UTS \#46 profile, not IDNA2008 / RFC 5891 conformance.\*\*
UTS \#46 is compatibility processing and deliberately differs from
IDNA2008 — it accepts labels IDNA2008 would reject (e.g.
\`"☕.example"\` becomes \`"xn–53h.example"\`). The pipeline draws on
RFC 3492 (the Punycode transform), NFC per UAX \#15, the RFC 5892
ContextJ rules via \`CheckJoiners\` (ZWJ/ZWNJ only — full RFC 5892
CONTEXTO is \*\*not\*\* checked), the RFC 5893 Bidi rule via
\`CheckBidi\`, and STD 3 (RFC 952 + RFC 1123) host-name rules via
\`UseSTD3ASCIIRules\`. IDNA2003 / Nameprep (RFC 3490/3491/3454) is not
used.

The default applies the full strict UTS \#46 profile
(\`uts46-nontransitional-std3-v1\`). The \`check_hyphens\`,
\`use_std3\`, and \`verify_dns_length\` arguments are UTS \#46
processing flags that can each be relaxed independently; pass the
\*same\* values to \[normalization_profile_info()\] to obtain the
identity of the resulting profile. These are standard UTS \#46
parameters, \*\*not\*\* a browser mode: \`CheckBidi\` and
\`CheckJoiners\` always apply and are never knobs, and full WHATWG host
policy (where \`beStrict = false\` flips exactly these three) lives
upstack in \`rurl\`, not here.

## See also

\[normalization_profile_info()\] for the profile identity,
\[puny_encode()\] for the lower-level RFC 3492 transform.

## Examples

``` r
host_normalize(c("Example.COM", "münchen.de", "example.com."))
#> [1] "example.com"       "xn--mnchen-3ya.de" "example.com."     
host_normalize("a_b.com") # NA: STD3 rejects "_"
#> [1] NA
host_normalize("a_b.com", use_std3 = FALSE) # "a_b.com"
#> [1] "a_b.com"
```
