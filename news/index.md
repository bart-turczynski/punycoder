# Changelog

## punycoder (development version)

### Bug fixes

- [`puny_decode()`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md)
  now rejects malformed A-label input consistently across backends. The
  in-tree fallback decoder previously accepted non letter-digit-hyphen
  (LDH) characters in a label’s literal section (e.g. `xn--(o)-...`) and
  echoed an empty Bootstring payload (`xn---`) back unchanged, where
  libidn2 rejected both. It now applies the documented LDH check to
  decode input and reports these as an error under `strict = TRUE` /
  `NA` under `strict = FALSE`, so the two backends agree on every input
  (PUNY-ypjwnagl, PUNY-rxvwqsou).

## punycoder 1.2.1

CRAN release: 2026-07-19

Maintenance release over the 1.2.0 development tag; the public API is
unchanged.

### Internal

- Added OSV and OSS Index dependency vulnerability audits, a
  `goodpractice`-aligned `.lintr`, pre-commit and community-health
  configuration, and Dependabot for GitHub Actions; no package code or
  user-facing change
  ([\#57](https://github.com/bart-turczynski/punycoder/issues/57),
  [\#58](https://github.com/bart-turczynski/punycoder/issues/58),
  [\#61](https://github.com/bart-turczynski/punycoder/issues/61),
  [\#63](https://github.com/bart-turczynski/punycoder/issues/63)).

## punycoder 1.2.0

### Breaking changes

- [`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
  no longer takes a `strict` argument. It was inert (always applied the
  full profile) and reserved for exactly this relaxed variant, which the
  three explicit flags below now provide.

### New features

- [`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
  gains three UTS
  [\#46](https://github.com/bart-turczynski/punycoder/issues/46)
  processing flags — `check_hyphens`, `use_std3`, and
  `verify_dns_length` — each defaulting to `TRUE` (the strict
  `uts46-nontransitional-std3-v1` profile) and each independently
  relaxable. These are standard UTS
  [\#46](https://github.com/bart-turczynski/punycoder/issues/46)
  parameters, not a browser mode: `CheckBidi` and `CheckJoiners` always
  apply, and full WHATWG host policy lives upstack. Pass the same flag
  values to
  [`normalization_profile_info()`](https://bart-turczynski.github.io/punycoder/reference/normalization_profile_info.md)
  for the matching profile identity.

### Deprecated

- [`url_encode()`](https://bart-turczynski.github.io/punycoder/reference/url_encode.md),
  [`url_decode()`](https://bart-turczynski.github.io/punycoder/reference/url_decode.md),
  and
  [`parse_url()`](https://bart-turczynski.github.io/punycoder/reference/parse_url.md)
  are deprecated and now emit a
  [`.Deprecated()`](https://rdrr.io/r/base/Deprecated.html) warning on
  use. They remain exported and fully functional for this release and
  are scheduled for removal in the next one. These were always
  best-effort host extraction/rewriting, not RFC 3986 / WHATWG URL
  parsing; use the `rurl` package for URL parsing and canonicalization,
  or pass the host alone to
  [`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
  /
  [`puny_encode()`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md)
  /
  [`puny_decode()`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md)
  for host-only needs.

### Minor improvements

- [`puny_encode()`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md)
  /
  [`puny_decode()`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md)
  now reject URL-shaped input with a dedicated, actionable error
  (`looks_like_url`) pointing at `rurl::get_host()`, instead of the
  generic “ASCII domain labels may contain only letters, numbers and
  hyphens” message. Behavior is unchanged (URLs were always rejected;
  only the message is clearer).

### Internal

- [`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
  is now verified against the official Unicode UTS
  [\#46](https://github.com/bart-turczynski/punycoder/issues/46)
  conformance corpus (`IdnaTestV2.txt`, Unicode 16.0.0). The suite
  confirms full non-transitional ToASCII conformance, with one
  documented profile divergence: the trailing FQDN root dot is permitted
  (strict `VerifyDnsLength` would reject the empty root label).

## punycoder 1.1.0

CRAN release: 2026-06-16

### New Features

- [`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
  converts hostnames to their canonical comparison form under a pinned
  UTS-46 profile (non-transitional, `UseSTD3ASCIIRules`, `CheckHyphens`,
  `CheckBidi`, `CheckJoiners`, NFC, DNS length verification), returning
  lowercase ASCII A-labels or `NA` for invalid input. The
  mapping/NFC/validation pipeline is implemented in-tree over vendored
  Unicode 16.0.0 data, so behavior is independent of whether libidn2 is
  present.
- [`normalization_profile_info()`](https://bart-turczynski.github.io/punycoder/reference/normalization_profile_info.md)
  exposes the machine-readable profile identity (`profile`,
  `unicode_version`, and the profile parameters) for downstream
  reproducibility keys.

## punycoder 1.0.0

CRAN release: 2026-06-11

First CRAN release.

### Bug Fixes

- [`puny_decode()`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md)
  (and the URL/domain decoders) now bound label length in both strict
  and non-strict mode. A crafted oversized `xn--` label previously drove
  the fallback decoder into quadratic time with unbounded allocation;
  oversized labels are now rejected promptly (error in strict mode, `NA`
  in non-strict).

### New Features

- Strict decoding now enforces RFC 5891 canonical A-label form: a
  decoded label must re-encode to itself. Non-canonical encodings
  (e.g. uppercase payloads) are rejected in strict mode while non-strict
  decoding stays lenient.
- Initial release of punycoder package
- Core punycode encoding and decoding functions
  ([`puny_encode()`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md),
  [`puny_decode()`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md))
- URL-aware processing functions
  ([`url_encode()`](https://bart-turczynski.github.io/punycoder/reference/url_encode.md),
  [`url_decode()`](https://bart-turczynski.github.io/punycoder/reference/url_decode.md),
  [`parse_url()`](https://bart-turczynski.github.io/punycoder/reference/parse_url.md))
- Domain validation and utility functions
  ([`is_punycode()`](https://bart-turczynski.github.io/punycoder/reference/is_punycode.md),
  [`is_idn()`](https://bart-turczynski.github.io/punycoder/reference/is_idn.md),
  [`validate_domain()`](https://bart-turczynski.github.io/punycoder/reference/validate_domain.md))
- Comprehensive test suite with RFC 3492 compliance testing
- High-performance C++ backend with Rcpp
- Vectorized operations for bulk processing
- Robust error handling and validation
- Complete documentation with vignettes

### Package Structure

- CRAN-compliant package structure
- MIT license
- Comprehensive test coverage
- Performance optimizations
- Cross-platform compatibility (Windows, macOS, Linux)

### Technical Implementation

- C++ backend using Rcpp for performance
- Placeholder implementation ready for libidn2 integration
- RFC 3492 compliance framework
- Extensive input validation
- Memory-efficient vectorized operations

### Documentation

- Complete function documentation with examples
- Introductory vignette
- README with quick start guide
- Test vectors from RFC 3492 specification

### Future Roadmap

- Integration with GNU libidn2 for production punycode implementation
- Performance optimizations
- Additional URL manipulation utilities
- Integration examples with popular R packages
