# punycoder (development version)

## Breaking changes

* The normalization profile token is now `uts46-nontransitional-std3-v3` (was `-v2`) because `verify_dns_length = FALSE` now keeps empty labels (below); default results are unchanged, but a key storing the token must be rebuilt (ADR-018).

* punycoder now requires R >= 4.1.0, up from 3.5.0 (`SEOR-wxelnnmt`).

## Bug fixes

* punycoder installs again with libidn2 older than 2.3.5 (Ubuntu 20.04 and 22.04, Debian 12), using its in-tree backend (`SEOR-wxelnnmt`).

* `host_normalize(verify_dns_length = FALSE)` now keeps empty labels instead of returning `NA`, per UTS #46 §4.2 step 4 and as Node's `url.domainToASCII()` does; the default is unchanged (`PUNY-fffgkhoj`).

## Documentation

* New `vignette("comparison")` compares punycoder with other Punycode libraries (`SEOR-kqmqosji`).

# punycoder 1.3.0

## Breaking changes

* The pinned Unicode version moved from 16.0.0 to 17.0.0 and the profile token to `uts46-nontransitional-std3-v2`; results only gain values, and token-keyed caches must re-key.

* punycoder ships the current and the previous Unicode version; a version is deprecated for one release cycle, still selectable, before it is dropped (ADR-017).

* `url_encode()`, `url_decode()` and `parse_url()`, deprecated in 1.2.0, are removed; use `rurl` for URLs, or pass the host to `host_normalize()`, `puny_encode()` or `puny_decode()`.

* `is_punycode()` and `is_idn()` now both return `FALSE`, with no warning, for input that is not well-formed UTF-8; `is_punycode()` used to return `TRUE`.

## New features

* `host_normalize()` and `normalization_profile_info()` gain `unicode_version`, and `unicode_versions()` lists the shipped versions; a non-default version appends `+unicode-<version>` to the token (ADR-016).

* `validate_domain()` results print a count header, stop after 10 domains and show each error's code; a new `summary()` method tallies errors by code.

* `host_normalise()` and `normalisation_profile_info()` are exported as British-spelling aliases of `host_normalize()` and `normalization_profile_info()` (`SEOR-qwomlgjd`).

## Bug fixes

* `URL:`, `BugReports:`, the documentation site (<https://bart-turczynski.gitlab.io/punycoder/>) and the vignette's tracker links moved from the suspended GitHub account to GitLab (PUNY-rsxtbbln).

* `puny_decode()` with the in-tree backend now rejects malformed A-labels (non-LDH literal characters, an empty `xn---` payload), so both backends agree on every input.

* `puny_encode()`, `puny_decode()` and `validate_domain()` transcode input to UTF-8 and mark Unicode output as UTF-8, so a Latin-1-marked host gets the same answer (#67).

## Performance

* `host_normalize()` returns input already in NFC untouched (UAX #15 quick check), about 1.2x faster on any mix of ASCII and non-ASCII hosts.

* `host_normalize()` looks up canonical composition through a trie, up to 1.05x faster on non-ASCII hosts.

* `host_normalize()` looks up four Unicode tables through two-stage tries, up to 1.25x faster on non-ASCII hosts, and the installed shared object is 64 KB smaller.

* `host_normalize()` answers ASCII without searching the Unicode tables: 1.75x faster on all-ASCII hosts, 1.12x on all-non-ASCII.

* `host_normalize()` is roughly 25-30% faster: labels from the label split are no longer re-normalized to NFC.

# punycoder 1.2.1

Maintenance release over the 1.2.0 development tag; the public API is unchanged.

* Unicode 17.0.0 tables ship alongside 16.0.0, unused by the public API, so normalization is unchanged; the installed shared object grows by about 250 KB (ADR-015).

# punycoder 1.2.0

## Breaking changes

* `host_normalize()` no longer takes a `strict` argument; it was inert, and the three flags below provide the relaxed variant.

## New features

* `host_normalize()` gains the UTS #46 flags `check_hyphens`, `use_std3` and `verify_dns_length`, each defaulting to `TRUE`; pass the same values to `normalization_profile_info()` for the matching profile.

## Deprecated

* `url_encode()`, `url_decode()` and `parse_url()` are deprecated with a warning and will be removed next release; use `rurl` for URL parsing, or pass the host to `host_normalize()`.

## Minor improvements

* `host_normalize()` is verified against UTS #46 IdnaTestV2 (16.0.0); a trailing root dot is accepted, unlike strict `VerifyDnsLength`.
* `puny_encode()` and `puny_decode()` reject URL-shaped input with a dedicated `looks_like_url` error pointing at `rurl::get_host()`; URLs were always rejected.

# punycoder 1.1.0

## New Features

* `host_normalize()` converts hostnames to a canonical comparison form under a pinned UTS-46 profile, returning lowercase A-labels or `NA`, on vendored Unicode 16.0.0 data with or without libidn2.
* `normalization_profile_info()` exposes the machine-readable profile identity (`profile`, `unicode_version`, and the profile parameters) for downstream reproducibility keys.

# punycoder 1.0.0

First CRAN release.

## Bug Fixes

* `puny_decode()` and the URL/domain decoders now bound label length in both strict and non-strict mode, rejecting oversized `xn--` labels that drove the fallback decoder into quadratic time.

## New Features

* Strict decoding now enforces RFC 5891 canonical A-label form (a decoded label must re-encode to itself); non-strict decoding stays lenient.
* Initial release of punycoder package
* Core punycode encoding and decoding functions (`puny_encode()`, `puny_decode()`)
* URL-aware processing functions (`url_encode()`, `url_decode()`, `parse_url()`)
* Domain validation and utility functions (`is_punycode()`, `is_idn()`, `validate_domain()`)
* Comprehensive test suite with RFC 3492 compliance testing
* High-performance C++ backend with Rcpp
* Vectorized operations for bulk processing
* Robust error handling and validation
* Complete documentation with vignettes
* Cross-platform: Windows, macOS and Linux.
