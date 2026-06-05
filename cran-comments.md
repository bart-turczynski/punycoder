## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

### Notes

**Possibly invalid URLs (404)**

The GitHub repository URLs (DESCRIPTION, README.md, man/punycoder-package.Rd) return 404 during
automated checking because the repository is currently private. It will be made public prior to
CRAN publication.

**checkbashisms not found**

The `checkbashisms` tool from the devscripts package is not installed in the local check
environment. The `configure` script uses only POSIX sh constructs (#!/bin/sh, printf, sed) and
has been manually reviewed for bashisms. CRAN's Linux check infrastructure, which has
checkbashisms installed, will perform the definitive check.

**HTML tidy version**

Skipping HTML validation because `tidy` is older than the checker expects. Not related to package
content.

## Platform

Tested locally on:

* macOS Tahoe 26.4.1 (aarch64), R 4.6.0, Apple clang 17.0.0
  * With libidn2 backend (brew install libidn2)
  * With fallback C++ backend

## Downstream dependencies

None — this is a new package.
