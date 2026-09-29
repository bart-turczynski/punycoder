## Submission

This is an update, 1.2.1 -> 1.3.0. It contains breaking changes, listed under
"Changes in this version" below, and it changes the results of one exported
function (`host_normalize()`) for a small set of inputs. Both reverse
dependencies are discussed at the end.

## R CMD check results

0 errors | 0 warnings | 1 note

The note is the `BugReports` URL, explained in the next section. Every check
below ran on the same package source, the one submitted: a tarball built from
a clean `git archive` export of commit 9774e6f.

* **local**, macOS Tahoe 26.7, aarch64-apple-darwin23, R 4.6.0, libidn2
  backend: `R CMD check --as-cran` with `_R_CHECK_CRAN_INCOMING_=true` and
  `_R_CHECK_CRAN_INCOMING_REMOTE_=true`. 0 errors | 0 warnings | 1 note.
* **macOS builder**, macOS 26.6, aarch64-apple-darwin23, R 4.6.1 Patched
  (2026-07-27 r90311): Status: OK.
* **win-builder**, x86_64-w64-mingw32:
  * R-oldrelease, R 4.5.3 (2026-03-11 ucrt): 0 errors | 0 warnings | 1 note.
    Besides the `BugReports` URL, the note lists "IDNA", "Punycode" and
    "selectable" as possibly misspelled in DESCRIPTION; all three are
    correct.
  * R-release, R 4.6.1 (2026-06-24 ucrt), and R-devel (2026-09-25 r90590
    ucrt): the package installed and the Windows binary built, but on each
    of two submissions `R CMD check` stopped at "checking CRAN incoming
    feasibility ..." with no result. For a package already on CRAN, R 4.6
    reads `src/contrib/Meta/current.rds` from the configured CRAN mirror and
    halts when the mirror answers 404; the first R-devel log carried a 404
    page from the builder's own server at that point. Reproduced in
    `rocker/r-ver:4.6.1`, whose default mirror lacks that file: the check
    halts at the same step, and with a mirror that serves it the step
    completes with only the `BugReports` note.
* **R-hub** (R Consortium runners), R-devel, Status: OK on each:
  * linux: Ubuntu 24.04.5 LTS, x86_64-pc-linux-gnu
  * macos: macOS Sequoia 15.7.9, x86_64-apple-darwin20
  * macos-arm64: macOS Tahoe 26.6.2, aarch64-apple-darwin23
  * windows: Windows Server 2022, x86_64-w64-mingw32
  * nold: Ubuntu 22.04.5 LTS, x86_64-pc-linux-gnu
  * clang-asan, clang-ubsan (Ubuntu 22.04.5 LTS) and gcc-asan (Fedora 42):
    no sanitizer reports
  * valgrind (Fedora 42): 0 errors, 0 bytes definitely lost
  * rchk: its only finding is in Rcpp's own header
    (`Rcpp/protection/Shield.h:25`, "possible protection stack imbalance"
    in `Rcpp::Rcpp_protect`), which rchk reports for Rcpp-based packages in
    general; nothing in this package's code.
* **GitLab CI**, `R CMD check --as-cran` in rocker/r-ver containers,
  aarch64-unknown-linux-gnu, libidn2 backend (pipeline 2895032359):
  * R 4.6.1 (2026-06-24), Ubuntu 24.04.4 LTS: 0 errors | 0 warnings | 0 notes
  * R 4.5.3 (2026-03-11), Ubuntu 24.04.4 LTS: 0 errors | 0 warnings | 0 notes
  * R-devel (2026-09-28 r90591), Ubuntu 26.04.1 LTS: 0 errors | 0 warnings |
    2 notes: the `BugReports` URL, and "compilation flags used" naming
    `-Wdate-time`, `-Werror=format-security` and `-Wformat`, which come from
    the image's own R build configuration; the package sets no compiler flags
    of its own.
  * clang-ASAN/UBSAN (R-hub's `clang-asan` container, R-devel 2026-09-25
    r90590, x86_64): tests, examples and vignette code run with no sanitizer
    reports. (Its two WARNINGs are the job's own doing: it builds with
    `--no-build-vignettes`, so the tarball it checks has no `inst/doc`.) The
    valgrind container cannot start on this CI's arm64 runner, so valgrind
    coverage is R-hub's, above.

Both Punycode backends are exercised where available: the optional libidn2
backend on Linux and macOS, and the in-tree fallback everywhere (Windows
builds always use the fallback). The test suite includes fallback-vs-libidn2
parity tests.

## Expected NOTE: the `BugReports` URL

The repository moved from GitHub to GitLab after 1.2.1, so `URL:` and
`BugReports:` now name gitlab.com (1.2.1 on CRAN still names the GitHub
account, which is suspended). An automated URL check is expected to report
the declared `BugReports:` address as a 404:

    Found the following (possibly) invalid URLs:
      URL: https://gitlab.com/bart-turczynski/punycoder/-/issues
        From: DESCRIPTION
              man/punycoder-package.Rd
        Status: 404
        Message: Not Found

This is how gitlab.com behaves, and the link is not broken. GitLab has
migrated issues to work items and answers `/-/issues` with 404 to any
signed-out, non-browser client, on every project on the site; GitLab's own
tracker, `https://gitlab.com/gitlab-org/gitlab/-/issues`, returns 404 the
same way. A browser is redirected to `/-/work_items`, so the page loads
normally by hand.

`DESCRIPTION` keeps `/-/issues` on purpose. The incoming check string-tests
this one field and accepts a gitlab.com `BugReports:` only when its path ends
in `/issues` (optionally `/new`), so it flags the working `/-/work_items`
address. The first 1.2.1 upload of the sibling package 'pslr' declared
`/-/work_items` and was archived at the incoming pretest on 2026-09-12 for
that NOTE; resubmitted with `/-/issues`, it was accepted. 'rurl' 3.0.1 and
'raddr' 0.1.2 are on CRAN with the same `/-/issues` form. The
`/-/work_items/issues` form satisfies the pattern but returns 403, so it is
not an option either. No gitlab.com address passes both checks, so this
submission accepts an explained NOTE rather than risk an archived upload.

Files a reader clicks through (`codemeta.json`, `SECURITY.md`, the intro
vignette) link `/-/work_items`, which returns 200. The incoming check reads
only `BugReports:`, so the two can differ without affecting the submission.

## Changes in this version

Full details are in NEWS.md. What a user or a reverse dependency can notice:

* **Breaking: the pinned Unicode version moved from 16.0.0 to 17.0.0, and the
  normalization profile token is now `uts46-nontransitional-std3-v2`** (was
  `-v1`). A `host_normalize()` call that names no `unicode_version` now uses
  the Unicode 17.0.0 IDNA mapping tables. In practice the change only adds
  accepted hosts: across both vendored UTS #46 conformance corpora and all 8
  flag combinations, the new default differs from 16.0.0 on 3 rows (16.0.0
  corpus) and 5 rows (17.0.0 corpus), and in every one of them `NA` became a
  value; no value changed. The token bump is what a caller has to act on:
  anything keyed on the token must re-key, and a stale key now misses loudly
  instead of colliding. The 16.0.0 tables still ship and can be selected with
  `unicode_version = "16.0.0"`, which returns the same results as 1.2.1.
* **Breaking: `url_encode()`, `url_decode()` and `parse_url()` are removed**,
  one release after they were deprecated in 1.2.0 with a `.Deprecated()`
  warning. They did best-effort host extraction and were never a URL parser.
  'rurl' covers URL parsing; `host_normalize()`, `puny_encode()` and
  `puny_decode()` cover hosts.
* **Breaking: `is_punycode()` and `is_idn()` now both return `FALSE` for
  input that is not well-formed UTF-8.** Previously `is_punycode()` silently
  returned `TRUE` for it, and `is_idn()` warned. Answers for well-formed input
  are unchanged.
* New: `host_normalize()` and `normalization_profile_info()` take a
  `unicode_version` argument, and a new `unicode_versions()` lists the table
  sets this build ships (`"16.0.0"`, `"17.0.0"`).
* New: `print()` and `summary()` methods make `validate_domain()` results
  readable for large inputs.
* New: `host_normalise()` and `normalisation_profile_info()` are exported as
  British-spelling aliases of `host_normalize()` and
  `normalization_profile_info()`. Each is the same function object as its
  primary and shares its help page.
* Fixes: the fallback `puny_decode()` now rejects malformed A-labels the same
  way the libidn2 backend does; `puny_encode()`, `puny_decode()` and
  `validate_domain()` now convert input to UTF-8 before native code sees it.
* `host_normalize()` is faster, with output unchanged on the conformance
  corpora under every flag combination.

## Reverse dependencies

There are two reverse dependencies on CRAN, both by the same maintainer:
'pslr' 1.2.1 (Imports `punycoder (>= 1.1.0)`) and 'rurl' 3.0.1 (Imports
`punycoder (>= 1.2.1)`). Neither calls the removed URL functions: in their
CRAN sources, 'pslr' uses `host_normalize()`, `normalization_profile_info()`
and `puny_decode()`, and 'rurl' uses `host_normalize()`, `puny_encode()`,
`puny_decode()` and `validate_domain()`.

<!-- Checked 2026-09-29 against the 1.3.0 release tarball built from
     5fd5a10 (sha256 54e0d0a6...5d24). If punycoder's R/ or src/ changes
     before submission, re-run against the tarball being submitted. Check the
     published tarballs, not the development trees: a development tree is
     what hid four test failures in pslr 1.1.1. -->

Both CRAN tarballs (pslr_1.2.1.tar.gz, rurl_3.0.1.tar.gz) were checked with
`R CMD check --as-cran` against the 1.3.0 release tarball, in a library where
every other dependency came from CRAN. Tests, examples and vignettes pass for
both. `revdepcheck::revdep_check()` against the same source, comparing
'punycoder' 1.2.1 with 1.3.0, found no new problems for either (0 new
errors, warnings or notes).

* 'pslr' 1.2.1: OK, with no example-timing NOTE. Expected impact: 'pslr'
  ships a pre-built index stamped with the `-v1` profile and Unicode 16.0.0.
  It compares both fields with the installed 'punycoder' and, on a mismatch,
  rebuilds the index in memory once per session, so it returns current
  answers rather than stale ones. An
  element-wise comparison of 'pslr' results under 'punycoder' 1.2.1 and the
  development version (about 9 million cells) found no previously returned
  value changed; some `NA` results became values. The rebuild takes time:
  'pslr' 1.2.0 measured it at 2.75 s, which pushed four examples past 5 s.
  The 1.2.1 check recorded in its own cran-comments, run on 2026-09-12
  against a development 'punycoder' 1.2.1.9000 (the Unicode 17.0.0 / `-v2`
  code this release ships), reported only its `BugReports` NOTE. A 'pslr'
  update that ships the index under `-v2`, removing the rebuild, is planned
  to follow this release.
* 'rurl' 3.0.1: OK apart from one NOTE local to the check machine ('V8' is
  not installed there, so the HTML manual's math rendering was skipped). Its
  test suite anticipates this release: a
  characterization test expects Unicode 16.0.0 / `-v1` from 'punycoder' 1.2.1
  and 17.0.0 / `-v2` from any later version.
