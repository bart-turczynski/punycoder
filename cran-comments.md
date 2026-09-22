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

## A note on the `BugReports` URL

The repository moved from GitHub to GitLab after the 1.2.1 submission the
results above describe, so that run never saw this; the next one will. An
automated URL check reports the declared `BugReports:` address
(`https://gitlab.com/bart-turczynski/punycoder/-/issues`) as **404**:

    Found the following (possibly) invalid URLs:
      URL: https://gitlab.com/bart-turczynski/punycoder/-/issues
        From: DESCRIPTION
              man/punycoder-package.Rd
        Status: 404
        Message: Not Found

This is a gitlab.com behavior, not a broken link: GitLab has migrated issues to
work items and answers `/-/issues` with 404 to any signed-out, non-browser
client, on every project on the site. The same request against
`https://gitlab.com/gitlab-org/gitlab/-/issues` -- one of the most public
trackers there -- returns 404 identically. A browser is redirected to
`/-/work_items`, which is why the page loads normally by hand. The address is
correct and is the one users need; it is not dropped.

**The field names `/-/issues` deliberately, and will keep naming it.** R's own
incoming check accepts a `github.com` or `gitlab.com` `BugReports:` only when
its path matches `/issues(/new)?/?$`, and NOTEs anything else, recommending
that form in its place. The sibling package 'pslr' declared `/-/work_items` on
its first 1.2.1 upload and was archived at the incoming pretest on 2026-09-12
for precisely that NOTE; resubmitted with `/-/issues`, it was accepted, as
'rurl' 3.0.1 and 'raddr' 0.1.2 are on CRAN carrying the same explained 404. The
`/-/work_items/issues` form satisfies the regex but resolves 403, so it is not
a third option. No gitlab.com address clears both checks, and the two do not
cost the same: this one trades an explained NOTE for an archived submission.

The metadata a reader clicks -- `codemeta.json`, `SECURITY.md`, the intro
vignette -- names `/-/work_items`, which returns 200. `BugReports:` is the only
field the incoming check inspects, so the two can differ at no risk to the
submission.

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

Tested locally (macOS aarch64, R release) and on GitLab CI:

* Ubuntu, R devel / release / oldrel-1
* Both the libidn2 backend (Linux + macOS) and the fallback C++ backend are
  exercised, including fallback-vs-libidn2 parity tests.

Windows and macOS coverage for this submission comes from win-builder and the
macOS builder rather than from CI; the project's CI is Linux-only since it
moved off GitHub Actions.

## Reverse dependencies

The only CRAN reverse dependency is 'pslr'. The breaking removal of the
`host_normalize()` `strict` argument was coordinated with 'pslr': its CRAN
version no longer passes that argument (it calls `host_normalize()` with
defaults, which is behavior-preserving and compatible with both 1.1.0 and
1.2.x). 'pslr' (>= 1.1.1) was updated on CRAN ahead of this submission, so its
reverse-dependency check passes against punycoder 1.2.1.
