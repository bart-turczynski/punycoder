# punycoder (development version)

## New Features

* `host_normalize()` converts hostnames to their canonical comparison form
  under a pinned UTS-46 profile (non-transitional, `UseSTD3ASCIIRules`,
  `CheckHyphens`, `CheckBidi`, `CheckJoiners`, NFC, DNS length verification),
  returning lowercase ASCII A-labels or `NA` for invalid input. The
  mapping/NFC/validation pipeline is implemented in-tree over vendored Unicode
  16.0.0 data, so behavior is independent of whether libidn2 is present.
* `normalization_profile_info()` exposes the machine-readable profile identity
  (`profile`, `unicode_version`, and the profile parameters) for downstream
  reproducibility keys.

# punycoder 1.0.0

First CRAN release.

## Bug Fixes

* `puny_decode()` (and the URL/domain decoders) now bound label length in both
  strict and non-strict mode. A crafted oversized `xn--` label previously drove
  the fallback decoder into quadratic time with unbounded allocation; oversized
  labels are now rejected promptly (error in strict mode, `NA` in non-strict).

## New Features

* Strict decoding now enforces RFC 5891 canonical A-label form: a decoded
  label must re-encode to itself. Non-canonical encodings (e.g. uppercase
  payloads) are rejected in strict mode while non-strict decoding stays lenient.
* Initial release of punycoder package
* Core punycode encoding and decoding functions (`puny_encode()`, `puny_decode()`)
* URL-aware processing functions (`url_encode()`, `url_decode()`, `parse_url()`)
* Domain validation and utility functions (`is_punycode()`, `is_idn()`, `validate_domain()`)
* Comprehensive test suite with RFC 3492 compliance testing
* High-performance C++ backend with Rcpp
* Vectorized operations for bulk processing
* Robust error handling and validation
* Complete documentation with vignettes

## Package Structure

* CRAN-compliant package structure
* MIT license
* Comprehensive test coverage
* Performance optimizations
* Cross-platform compatibility (Windows, macOS, Linux)

## Technical Implementation

* C++ backend using Rcpp for performance
* Placeholder implementation ready for libidn2 integration
* RFC 3492 compliance framework
* Extensive input validation
* Memory-efficient vectorized operations

## Documentation

* Complete function documentation with examples
* Introductory vignette
* README with quick start guide
* Test vectors from RFC 3492 specification

## Future Roadmap

* Integration with GNU libidn2 for production punycode implementation
* Performance optimizations
* Additional URL manipulation utilities
* Integration examples with popular R packages 