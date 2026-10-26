# Continuous integration (GitLab CI)

All CI lives in a single `.gitlab-ci.yml`. It replaced eight GitHub Actions
workflows when the project went GitLab-only; `.github/` no longer exists.

The **gate** is `gates`, `check`, `coverage`. `gates` runs `scripts/gates.R`,
which folds the `lint`, `readme` and `news-version` checks that `verify.yml` and
`news-version.yaml` used to run, plus `spelling` and `docs-drift`, into one job:
it runs all of them, prints a PASS/FAIL line for each, and fails if any failed
(SEOR-pgammbgo, ADR 0005 in seor). `docs-drift` regenerates `man/`,
`NAMESPACE` and `DESCRIPTION` with the pinned roxygen2 and fails when they
differ from what is committed, the same check the pre-push gate runs first (SEOR-nwfmerhu).
`check` runs `R CMD check --as-cran` and fails on a WARNING; `coverage` fails
below 95% total coverage, the fleet minimum.

Read "gate" carefully: **it does not run on your merge request.** A top-level
`workflow:` block admits only a tag, a push to `main`, or a pipeline a human
started by hand, so a feature-branch push and its merge request both create
*no pipeline at all* — not a red one, none (SEOR-bmgkzhvy). A clean pipeline
list on a branch is therefore not a passing result. What actually gates a
merge is `main` being protected plus the `pre-commit` pre-push hook, which
runs the same chain locally before the branch leaves your machine.

To get a server-side answer on a branch before merging it, start a pipeline
yourself at **Build > Pipelines > Run pipeline** and pick the ref. The three
gate jobs run there, and `full-check` and `sanitizers` become one click away.

To run `full-check` and `sanitizers` on `main` from the terminal, for example
before a CRAN submission, start an API pipeline with the `DEEP_CHECK` variable:

```sh
glab ci run --branch main --variables DEEP_CHECK:1
glab ci status --branch main --wait
```

Both jobs start at once, not as manual jobs, and neither is allowed to fail.
The trigger works on `main` only: the `workflow:` rules give an API pipeline
on any other branch nothing. Without `DEEP_CHECK:1`, `glab ci run` starts only
the jobs a push to `main` would run.

Everything else is opt-in:

| Job | When |
| --- | --- |
| `full-check` | release tags `v*`; the `deep-check` schedule; an API pipeline on `main` with `DEEP_CHECK=1`; manual from a hand-started pipeline, on any ref |
| `floor-check` | `R CMD check --as-cran` on R 4.1.3, the declared floor, with dependencies from a dated Posit Package Manager snapshot; same triggers as `full-check` |
| `sanitizers` | R-hub's clang-ASAN/UBSAN container (no valgrind: see the release checklist): the `deep-check` schedule; an API pipeline on `main` with `DEEP_CHECK=1`; manual on a release tag or a hand-started pipeline |
| `pages` | every push to `main` — builds pkgdown, publishes to GitLab Pages. Pinned to `main`: a hand-started branch pipeline cannot reach it. Strips agent instruction files first, see below |
| `codemeta` | manual, artifact-only (see below) |
| `osv-audit`, `security-audit` | a pipeline schedule that sets `SCHEDULE_KIND=dependency-audit`; manual from a hand-started pipeline. Never on a push |

Five things about it are non-obvious enough to be worth stating:

- **The `pages` job deletes files before it builds.** It strips the agent instruction files first — pkgdown renders every top-level `.md`, so `AGENTS.md`, `CLAUDE.md` and the `FP_*.md` files were being published next to the function reference as `AGENTS.html`, `CLAUDE.html` and friends: internal working notes served as if they were user documentation (SEOR-pibdjanz). The job uses a **keep-list**, not a glob: immediately before `build_site`, every top-level `.md` not named in its `KEEP` variable is moved out of the tree, so a new agent file of any name stays private (SEOR-wqxhftpv). The flip side: a new top-level `.md` meant for the public site is not published until you add it to `KEEP` in the same commit, and a `KEEP` entry whose file is missing fails the job.

- **Pandoc is pinned, and the pin is load-bearing.** The `readme` check
  asserts that `README.md` matches a fresh knit of `README.Rmd` (blank-line-only
  differences aside, SEOR-kaqtnovh), and
  pandoc's markdown writer changes table layout between versions — Ubuntu's
  apt pandoc rewrites every pipe table column-padded, so the job fails on
  whitespace and reports "out of sync" for a reason unrelated to the content.
  CI installs pandoc **3.10**, which is what reproduces the committed
  `README.md` byte for byte. **Keep your local pandoc on the same version**, or
  your `devtools::build_readme()` will produce a diff CI rejects (and vice
  versa). Bumping the pin means re-knitting `README.md` in the same change.

- **`dependencies = TRUE` on the `deps::.` ref is not optional.** Without it
  pak resolves hard dependencies only, and `R CMD build` dies with "vignette
  builder 'knitr' not found" — knitr and testthat are `Suggests`, which the
  old `needs: check` in the r-lib actions pulled in implicitly.
- **`NOT_CRAN` is never set globally.** `test-osv.R` and `test-security.R` call
  `skip_on_cran()`, so setting it package-wide would un-skip them inside
  `R CMD check`, where their network access and credentials are absent. Only
  the two audit jobs set it.
- **`codemeta` does not commit.** The GitHub workflow regenerated
  `codemeta.json` and pushed the result to `main`. That does not port: GitLab's
  `CI_JOB_TOKEN` cannot push, and the committed file now carries hand-set
  GitLab URLs (`contIntegration` points at the pipelines page) that `codemetar`
  cannot infer and would overwrite. The job is manual and emits the regenerated
  file as an artifact — download it, diff it, merge in what is genuinely new.
- **No Dependabot.** Its only ecosystem was `github-actions`. GitLab CI pins
  images by floating tag deliberately, so there is nothing there to bump; the
  one remaining pinned external ref is in `.pre-commit-config.yaml`, kept
  current with `pre-commit autoupdate`.

## Project settings CI depends on, which are not in this repository

These live in GitLab's project settings, so a fresh clone does not carry them
and a `git diff` will never show them missing:

- **Pipeline schedule** (Build > Pipeline schedules): schedule 4427280,
  "Weekly dependency vulnerability audits (osv-audit, security-audit)",
  `17 10 * * 1` Europe/Warsaw on `main`, carrying the schedule variable
  `SCHEDULE_KIND=dependency-audit`. `osv-audit` and `security-audit` run only
  on a scheduled pipeline with that value (or by hand from a `web` pipeline),
  so without the schedule, or without its variable, they never run
  unattended. The selector is what stops the second schedule, below, from
  firing the audits too.
- **Pipeline schedule** (Build > Pipeline schedules): schedule 4466444,
  "Weekly deep check (full-check, sanitizers)", `0 21 * * 1` Europe/Warsaw on
  `main`, carrying `SCHEDULE_KIND=deep-check`. It is the only unattended run of
  `full-check` and `sanitizers`; without it they run only before a release or
  by hand, and OpenSSF `dynamic_analysis_unsafe` ("routinely used") in
  `.bestpractices.json` is no longer true. It was documented here long before
  it existed (PUNY-pxfqjjgg), so check the schedule list, not this file.
- **`OSSINDEX_USER` / `OSSINDEX_TOKEN`** (Settings > CI/CD > Variables;
  `OSSINDEX_TOKEN` masked): Sonatype OSS Index credentials. These were GitHub
  repository secrets and did not follow the move. `security-audit` sets
  `OSSINDEX_AUDIT_REQUIRED=true`, so while they are absent the job **fails**
  and names what is missing, rather than skipping and passing green having
  audited nothing. Everywhere else `test-security.R` still skips without them.
- **`pages_access_level: public`** (Settings > General > Visibility): required
  for the `pages` job's output to be reachable by anyone but a member.
- **Pages unique domain off** (Deploy > Pages): the site lives at the
  namespace path `https://bart-turczynski.gitlab.io/punycoder/`, the fleet
  standard (SEOR-hcmtspmv), which `_pkgdown.yml` and `DESCRIPTION` name.
