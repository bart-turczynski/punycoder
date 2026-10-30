# Continuous integration

punycoder runs fleet-ci's tiered CI (seor ADR 0012). `.gitlab-ci.yml`
includes fleet-ci's `templates/r-package.yml`, pinned by commit SHA, and sets
only package variables; `.fleet-ci.yml` holds the local gate's settings, and
`.fleet-ci/` is fleet-ci's vendored gate (re-run fleet-ci's `bin/vendor`,
never edit it). The job names below are the template's.

| Tier | Where | What runs |
| --- | --- | --- |
| hygiene hooks | pre-commit, at commit and at push | `.pre-commit-config.yaml`. At commit and again at push: the hygiene fixers (end of file, trailing whitespace, line endings), the large-file, merge-conflict, YAML and case-conflict checks, and codespell. At push only: the citation, BugReports, NEWS and toolchain checks, the `check-news.py` and `bestpractices-url.py` self-tests when those scripts change, and the `fleet-ci-hook-installed` check (refuses the push when fleet-ci's hook is not installed) |
| T0 | every push whose diff against `main` is docs-only (`design/**/*.md` and the like), locally, the pre-push hook | the gate's docs tier, `.fleet-ci/gate` in the fleet image: spelling and `pkgdown::check_pkgdown()` |
| T1 | every other push, locally, the pre-push hook | the gate's full tier: T0's checks, then docs drift, lintr, README drift, NEWS heading, the URL check and one `R CMD check --as-cran` (incoming checks off) |
| T2 | the weekly `deep-check` schedule; every T3 run | `t2-check-release`, `t2-check-oldrel`, `t2-check-devel`, `t2-floor` (R 4.1.3), `t2-sanitizers` (R-hub clang-ASAN/UBSAN), `t2-locale`, `t2-ascran`, `coverage` (fails below 95%), `osv-audit`, `security-audit`, `citation-version` |
| T3 | a `RELEASE=1` web pipeline on `main`; a `v*` tag | all of T2 plus `t3-manual`; the tag, or `RELEASE=1` on a tag, adds `pages` |

Pushes to `main` or a branch, merge requests and API pipelines (`glab ci run`)
create no pipeline at all. An empty pipeline list is not a pass: the merge
gate is the local gate (T0 or T1), run before the branch leaves the machine.

Before a CRAN submission, start T3 on `main` from **Build > Pipelines > Run
pipeline**, ref `main`, variable `RELEASE=1` (see
[release-deltas.md](release-deltas.md)). `PAGES=1` on a `v*` tag runs `pages`
alone.

## The hook, once per clone

```sh
.fleet-ci/pre-push --install
```

It runs the gate on each pushed ref's tip, then the pre-commit pre-push
stage. Two commands drop it: `pre-commit install -f`, which installs both
hook types (`.pre-commit-config.yaml`'s `default_install_hook_types`), and
`pre-commit install -f --hook-type pre-push`; re-run the install after
either. Without `-f`, `pre-commit install` (with or without
`--hook-type pre-push`) moves the hook to `hooks/pre-push.legacy`
(pre-commit's migration mode), which still runs the gate first; `-f
--hook-type pre-commit` leaves it alone. `.fleet-ci/gate auto` runs the gate by
hand on `HEAD`. A pass is stamped by tree, tier, classifier version, image
and (full tier) resolved dependency lock, and a stamped commit is skipped.

## Project settings CI depends on, which are not in this repository

These live in GitLab's project settings, so a clone does not carry them:

- **Pipeline schedule 4466444** (Build > Pipeline schedules), "Weekly deep
  check", `0 21 * * 1` Europe/Warsaw on `main`, carrying
  `SCHEDULE_KIND=deep-check`. Required: it is T2's only unattended run, and
  without it OpenSSF `dynamic_analysis_unsafe` ("routinely used") in
  `.bestpractices.json` is no longer true.
- **Pipeline schedule 4427280**, `SCHEDULE_KIND=dependency-audit`. The
  template starts no pipeline for it any more (the audits run in T2); its
  removal is owner-gated, seor SEOR-uldurjev.
- **`OSSINDEX_USER` / `OSSINDEX_TOKEN`** (Settings > CI/CD > Variables;
  `OSSINDEX_TOKEN` masked). `security-audit` sets
  `OSSINDEX_AUDIT_REQUIRED=true`, so without them it fails rather than
  passing having audited nothing.
- **`pages_access_level: public`** and **Pages unique domain off**: the site
  lives at `https://bart-turczynski.gitlab.io/punycoder/`, which
  `_pkgdown.yml` and `DESCRIPTION` name. `pages` publishes only the top-level
  `.md` files on `.fleet-ci.yml`'s `pages_keep`.

## Gaps accepted in the fleet-ci migration

- **No `codemeta` job.** The template has no base for a manual job, so the
  old artifact-only job was dropped. Regenerate `codemeta.json` by hand with
  `codemetar` when needed, and keep its hand-set GitLab URLs.
- **Only the release legs build with libidn2.** `t2-check-release`,
  `t2-ascran` and `coverage` run on `fleet-r-idn2`
  (`FLEET_RELEASE_VARIANT`); `t2-check-oldrel`, `t2-check-devel`, `t2-floor`,
  `t2-sanitizers`, `t2-locale` and `t3-manual` have no libidn2 image in the
  template and check the fallback build.
- **No valgrind in CI.** R-hub's valgrind image is x86_64, so on this
  project's arm64 runner it runs under Rosetta 2, and no R process starts
  there: its GCC-built R uses the x87 instruction `ffreep` at every startup,
  which Rosetta does not implement (`Rscript` dies with SIGILL). The
  clang-built `clang-asan` image that `t2-sanitizers` uses does not emit it.
  Do not add a valgrind leg unless the runner is x86_64. A native arm64
  valgrind on `rocker/r-ver` runs, but that R is not built with valgrind
  instrumentation and is not CRAN's platform, so a green run there would
  look stronger than it is. Valgrind runs on R-hub's x86_64 runners instead
  ([release-deltas.md](release-deltas.md), step 6).
- **Coverage measures the libidn2 build**, not the fallback one.
- **`NOT_CRAN=true` in T1 and the T2 check legs.** The performance
  throughput floors in `test-performance.R` run there, and the T2 check legs
  also run `test-osv.R` (network); T1 excludes `test-osv.R` and
  `test-security.R` (`.fleet-ci.yml`'s `exclude_tests`).
- **Pandoc** comes from the fleet image (`.fleet-ci/toolchain`, 3.10), which
  reproduces the committed `README.md`. `scripts/check-toolchain.R` checks a
  local pandoc against it, so a local `build_readme()` writes what the gate
  accepts.
