## R CMD check results

0 errors | 0 warnings | 1 note

The incoming-feasibility NOTE flags three things:

* A short interval since the last update (1.1.0). The quick turnaround is to land
  a coordinated breaking change before the ecosystem grows: 1.1.0 introduced
  `host_normalize()` only yesterday, so the inert `strict` argument removed here
  has essentially no installed base, and removing it now (rather than after wider
  adoption) keeps the disruption to the single, already-coordinated reverse
  dependency. Apologies for the quick turnaround.
* A maintainer email change, from `bartek+punycoder@turczynski.pl` to
  `bartek@turczynski.pl`. This is the same maintainer (Bart Turczynski); the
  address was normalized to drop the per-package plus-tag alias. No change of
  person or organization.
* Possibly misspelled words in DESCRIPTION (IDNA, WHATWG, canonicalizers,
  parsers). These are valid technical terms from the IDN/URL domain, not
  misspellings.

## Changes in this version

This is a feature release (1.1.0 -> 1.2.1) for the UTS #46 host-normalization
API introduced in 1.1.0. (The 1.2.0 development tag was never submitted to CRAN;
1.2.1 adds only maintenance/tooling on top of the same public API.)

* Breaking: `host_normalize()` no longer accepts the `strict` argument. It was
  inert in 1.1.0 (the full profile always applied) and is replaced by three
  explicit UTS #46 flags below.
* New: `host_normalize()` gains `check_hyphens`, `use_std3`, and
  `verify_dns_length`, each defaulting to the strict
  `uts46-nontransitional-std3-v1` profile and independently relaxable.
  `normalization_profile_info()` reflects the chosen flags in its identity.
* Deprecated: `url_encode()`, `url_decode()`, and `parse_url()` now emit a
  `.Deprecated()` warning. They remain exported and functional this release and
  are scheduled for removal next release.

## Platform

Tested locally and on GitHub Actions:

* macOS (aarch64), R release
* Ubuntu, R devel / release / oldrel-1
* Windows, R release
* Both the libidn2 backend (Linux + macOS) and the fallback C++ backend
  (Windows) are exercised, including fallback-vs-libidn2 parity tests.

## Reverse dependencies

The only CRAN reverse dependency is 'pslr'. The breaking removal of the
`host_normalize()` `strict` argument was coordinated with 'pslr': its CRAN
version no longer passes that argument (it calls `host_normalize()` with
defaults, which is behavior-preserving and compatible with both 1.1.0 and
1.2.x). 'pslr' (>= 1.1.1) was updated on CRAN ahead of this submission, so its
reverse-dependency check passes against punycoder 1.2.1.
