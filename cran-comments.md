## R CMD check results

0 errors | 0 warnings | 1 note

This is a minor feature release (1.0.0 -> 1.1.0).

The NOTE is "Days since last update: 4". This update follows 1.0.0 closely on
purpose: it only *adds* the canonical-host normalization API
(`host_normalize()`, `normalization_profile_info()`) and changes nothing about
the existing 1.0.0 functions or their behavior. The new API unblocks a
downstream package ('pslr') that is ready for its own submission and depends on
it. Apologies for the quick turnaround.

## Changes in this version

* New `host_normalize()` and `normalization_profile_info()` functions for
  canonical-host normalization under a pinned UTS-46 profile (Unicode 16.0.0).
  The mapping/NFC/validation pipeline is implemented in-tree, so behavior is
  independent of whether the optional libidn2 backend is present.

## Platform

Tested locally and on GitHub Actions:

* macOS (aarch64), R release
* Ubuntu, R devel / release / oldrel-1
* Windows, R release
* Both the libidn2 backend (Linux + macOS) and the fallback C++ backend
  (Windows) are exercised, including fallback-vs-libidn2 parity tests.

## Downstream dependencies

None on CRAN. The in-development 'pslr' package depends on this release but is
not yet published.
