# Dependency and license scanning

FOSSA and Socket scan this repository's dependencies. On the **free FOSSA plan
the policy rule columns are view-only** — licenses cannot be batch-approved
and custom policies cannot be created or cloned — so there is no `.fossa.yml`
and no policy-level fix. The only lever is per-issue triage in the FOSSA admin
panel (ignore + note), which persists server-side across scans.

Triage rule when a license flag fires:

- **GPL / LGPL / MPL**, any version — including `GPL-2.0-or-later` for Rcpp and
  `GPL-3.0-only` for knitr/rmarkdown — **ignore with a note**. These are
  GPL-compatible with this package's MIT license, the source is already
  published on CRAN and GitLab, so the copyleft source-disclosure obligation is
  already satisfied. This is standard CRAN practice.
- **AGPL or proprietary — stop and evaluate.** AGPL closes the SaaS loophole and
  is the one copyleft that can actually bite. No current dependency is AGPL.

The dependency surface is tiny and stable (Rcpp is the only linked dependency;
knitr, rmarkdown and testthat are dev-only `Suggests`), so new flags should only
appear when a new dependency is added or an existing one relicenses.
