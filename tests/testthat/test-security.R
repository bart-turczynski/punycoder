# OSS Index dependency vulnerability audit (oysteR / Sonatype).
#
# `oysteR::audit_description()` resolves the installed DESCRIPTION and audits
# punycoder's hard dependencies against the Sonatype OSS Index. It is a
# network test that requires OSS Index credentials (OSSINDEX_USER /
# OSSINDEX_TOKEN): the API rejects unauthenticated requests with HTTP 401.
#
# Scope: hard dependencies only -- `Depends` + `Imports`, never `Suggests`.
#
# `oysteR::expect_secure()` audits `Depends` + `Imports` + `Suggests`, and
# `Suggests` drags in the recursive dependency trees of the dev tooling --
# including oysteR's own, which reaches `curl` through httr. So the gate was
# failing on a vulnerability in the auditor rather than in anything a user of
# punycoder installs.
#
# Measured 2026-09-10, same machine and credentials:
#
#     fields = Depends+Imports              3 packages audited, clean
#     fields = Depends+Imports+Suggests    78 packages audited, reports curl
#
# `curl` is absent from punycoder's hard dependency tree entirely. The two
# flagged advisories -- CVE-2026-18924 (CWE-416 use-after-free, CVSS 9.1) and
# CVE-2026-3783 (CWE-522 insufficiently protected credentials, CVSS 6.9) --
# both name libcurl ranges that include CRAN's current `curl` 8.0.0, so no
# available version clears them and no local action could make the old scope
# pass. PUNY-vymqxjnf carries the full measurement.
#
# A package's security posture is what it makes users install, so the audit
# calls `audit_description()` directly with the narrower `fields`.
# `expect_secure()` sets a CRAN mirror internally and `audit_description()`
# does not, hence the explicit `repos` option.
#
# The audit gates on dispositions, not on silence: every reported advisory
# must have a row in the allow-list in helper-security.R, and every row must
# still be reported (SEOR-fftbjnpl). The rules are documented there.
#
# WHERE THIS RUNS, AND WHY THE PRECONDITIONS ARE NOT ALWAYS SKIPS.
#
# Everywhere ordinary -- a local `testthat::test_local()`, the pre-push verify
# gate, a plain `R CMD check --as-cran` -- a missing precondition is a skip.
# That is right: a developer without OSS Index credentials is not a security
# regression.
#
# In the ONE place that exists to run this audit, it is not right. The
# `security-audit` CI job had no credentials (the GitHub repository secrets did
# not follow the move to GitLab), so `skip_if()` fired, the job reported
# success, and nothing had been audited (PUNY-rsxtbbln). A green job that
# audited nothing is worse than no job, because it answers the question it was
# never asked.
#
# So under OSSINDEX_AUDIT_REQUIRED=true every precondition below becomes a hard
# failure with a message naming what is missing. The flag is meant to be set
# in the `security-audit` job in `.gitlab-ci.yml` and nowhere else, so no other
# context changes behaviour. As of this commit the job does NOT set it yet:
# that half of SEOR-fftbjnpl is deferred until the pending CI consolidation
# (MR !26, which rewrites `.gitlab-ci.yml`) merges. This file already honours
# the flag, so enabling the gate is a one-line variable in that job.
#
# NOTE ON THE PRE-PUSH HOOK. This repository's pre-push `verify` hook is inline
# R in `.pre-commit-config.yaml`: `lintr::lint_package()`, then
# `rcmdcheck::rcmdcheck(args = "--as-cran", error_on = "warning")` with the
# default environment. Neither sets NOT_CRAN -- measured 2026-09-24 with
# testthat 3.3.2 and rcmdcheck 1.4.0, a probe test under `rcmdcheck()` saw
# NOT_CRAN empty and `skip_on_cran()` firing -- so the audit never runs on
# push, even though `~/.Renviron` puts the credentials in scope inside R. It
# runs under `testthat::test_local()`, which sets NOT_CRAN=true.

test_that("the OSS Index allow-list is well formed", {
  expect_equal(oss_index_allowlist_violations(oss_index_allowlist), character())
})

test_that("the allow-list validator rejects rows that are not decisions", {
  sound <- list(
    id = "CVE-2026-18924",
    package = "curl",
    version_seen = "8.0.0",
    review = as.Date("2026-12-01"),
    reason = paste(
      "A rationale long enough to be an argument rather than a placeholder,",
      "naming the advisory, the exposure assessed and why it is accepted."
    )
  )
  expect_equal(oss_index_allowlist_violations(list(sound)), character())

  broken <- function(field, value) {
    row <- sound
    row[[field]] <- value
    oss_index_allowlist_violations(list(row))
  }

  expect_match(
    broken("id", "GHSA-xxxx"),
    "single CVE identifier",
    fixed = TRUE
  )
  expect_match(broken("package", ""), "single package name", fixed = TRUE)
  expect_match(
    broken("version_seen", "not-a-version"),
    "parseable version",
    fixed = TRUE
  )
  expect_match(broken("review", "2026-12-01"), "single Date", fixed = TRUE)
  expect_match(
    broken("reason", "unfixable"),
    "too short to be an argument",
    fixed = TRUE
  )

  expect_match(
    oss_index_allowlist_violations(list(sound[-5])),
    "missing field(s): reason",
    fixed = TRUE
  )
  expect_match(
    oss_index_allowlist_violations(list(c(sound, list(owner = "me")))),
    "unknown field(s): owner",
    fixed = TRUE
  )
  expect_match(
    oss_index_allowlist_violations(list(sound, sound)),
    "duplicate allow-list id",
    fixed = TRUE
  )
})

test_that("hard dependencies report only allow-listed OSS Index advisories", {
  # The dedicated, credentialed audit job. A precondition it cannot meet is a
  # failure there, never a skip -- see the header.
  required <- identical(Sys.getenv("OSSINDEX_AUDIT_REQUIRED"), "true")
  no_credentials <- Sys.getenv("OSSINDEX_USER") == "" ||
    Sys.getenv("OSSINDEX_TOKEN") == ""

  if (required) {
    if (!requireNamespace("oysteR", quietly = TRUE)) {
      stop(
        "OSSINDEX_AUDIT_REQUIRED is set but {oysteR} is not installed, so ",
        "this job cannot audit anything. Install it or unset the flag; do ",
        "not let the job report success."
      )
    }
    if (no_credentials) {
      stop(
        "OSSINDEX_AUDIT_REQUIRED is set but OSSINDEX_USER / OSSINDEX_TOKEN ",
        "are absent, so OSS Index would reject every request with HTTP 401 ",
        "and this job would report success having audited nothing. Add both ",
        "as CI/CD variables (project Settings > CI/CD > Variables); the ",
        "commands are in the `security-audit` job in .gitlab-ci.yml."
      )
    }
    # Deliberately no skip_if_offline() on this path: a network the job cannot
    # reach is the same vacuous green as a credential it does not have, so let
    # the audit attempt the call and fail on the transport error.
  } else {
    skip_on_cran()
    skip_if_not_installed("oysteR")
    skip_if_offline()
    skip_if(
      no_credentials,
      "OSS Index credentials (OSSINDEX_USER / OSSINDEX_TOKEN) not set"
    )
  }

  old_repos <- getOption("repos")
  on.exit(options(repos = old_repos), add = TRUE)
  options(repos = c(CRAN = "https://cran.rstudio.com"))

  audit <- oysteR::audit_description(
    dirname(system.file("DESCRIPTION", package = "punycoder")),
    fields = c("Depends", "Imports"),
    verbose = FALSE
  )
  found <- oss_index_reported(audit)
  allowed <- vapply(oss_index_allowlist, function(row) row$id, character(1))

  # An audit that resolved nothing is not a clean audit. Without this an empty
  # result satisfies rules A and B vacuously, which is the same green-on-
  # nothing failure the credential guard above exists to stop.
  expect_gt(nrow(audit), 0)

  # Rule A -- an advisory reported and not allow-listed.
  expect_equal(sort(setdiff(found$id, allowed)), character())

  # Rule B -- an allow-listed advisory no longer reported. The list may not
  # over-permit, so a row that has outlived its justification fails here.
  expect_equal(sort(setdiff(allowed, found$id)), character())

  # Rule C -- drift warns, never fails. See helper-security.R.
  for (row in oss_index_allowlist) {
    if (Sys.Date() > row$review) {
      warning(
        sprintf(
          "OSS Index allow-list row %s is past its %s review date.",
          row$id,
          format(row$review)
        ),
        call. = FALSE
      )
    }
    hit <- found[found$id == row$id, ]
    if (
      nrow(hit) > 0 &&
        package_version(hit$version[1]) > package_version(row$version_seen)
    ) {
      warning(
        sprintf(
          paste(
            "OSS Index allow-list row %s was written against %s %s;",
            "the audit now reports %s. Re-read the advisory."
          ),
          row$id,
          row$package,
          row$version_seen,
          hit$version[1]
        ),
        call. = FALSE
      )
    }
  }
})
