# Contributing

## Orientation

Before making changes, skim [ARCHITECTURE.md](ARCHITECTURE.md) (how the package
is layered and where each responsibility lives) and [DECISIONS.md](DECISIONS.md)
(the ADR log explaining the load-bearing design choices — scope, normalization
profile, backend model, error policy, deprecations). Normalization behavior is
specified normatively in [dev/normalization-contract.md](dev/normalization-contract.md).

## Workflow

- Open an issue or discussion before large behavioral changes.
- Add or update tests for every user-visible change.
- Keep exported function signatures and object shapes stable unless the change is explicitly planned as breaking.
- Prefer small, reviewable patches over broad rewrites without coverage.

## Native Code

- The C++ implementation is split by subsystem under `src/`.
- Keep backend-specific logic inside the backend adapter layer rather than spreading `#ifdef` checks through domain or URL code.
- Preserve current R-facing error prefixes when changing internal error handling.

## Validation

- Run `testthat` locally when a compile toolchain is available.
- For packaging changes, run `R CMD check --as-cran` before release work.
- For performance work, the clean rebuild and the measurement protocol in
  [dev/perf-measurement.md](dev/perf-measurement.md) are the gate — a timing
  taken without them is not evidence.

### Doc-only changes skip the heavy gate

A change to `.md` / `.Rmd` / vignette prose / roxygen comment blocks cannot
affect the native build, so it does **not** need the clean `rm -f src/*.o`
rebuild, does not need `R CMD build` + `R CMD check --as-cran`, and should not
sit waiting on the slow report-only CI jobs (the `coverage` job in
`.gitlab-ci.yml` routinely spends 20–30 minutes installing dependencies on a
cold cache). Commit, push, merge.

Still do the cheap things that *are* implicated, because CI checks them:

- re-knit `README.md` when `README.Rmd` changes (the `readme` job checks they
  are in sync);
- run `roxygenise()` and commit `man/` when roxygen blocks change;
- keep `NEWS.md` consistent with the `DESCRIPTION` version (the `news-version`
  job checks the top heading).

Anything touching `R/`, `src/`, or `tests/` is not doc-only — run the normal
gate there.

## Continuous integration (GitLab CI)

All CI lives in a single `.gitlab-ci.yml`. It replaced eight GitHub Actions
workflows when the project went GitLab-only; `.github/` no longer exists.

The **gate** is `lint`, `readme`, `news-version`, `check`, `coverage` — the
same five checks, under the same names, that `verify.yml` and
`news-version.yaml` used to run.

Read "gate" carefully: **it does not run on your merge request.** A top-level
`workflow:` block admits only a tag, a push to `main`, or a pipeline a human
started by hand, so a feature-branch push and its merge request both create
*no pipeline at all* — not a red one, none (SEOR-bmgkzhvy). A clean pipeline
list on a branch is therefore not a passing result. What actually gates a
merge is `main` being protected plus the `pre-commit` pre-push hook, which
runs the same chain locally before the branch leaves your machine.

To get a server-side answer on a branch before merging it, start a pipeline
yourself at **Build > Pipelines > Run pipeline** and pick the ref. The five
gate jobs run there, and `full-check` and `sanitizers` become one click away.

Everything else is opt-in:

| Job | When |
| --- | --- |
| `full-check` | release tags `v*`; manual from a hand-started pipeline, on any ref |
| `sanitizers` | manual — R-hub's clang-ASAN/UBSAN and valgrind containers |
| `pages` | every push to `main` — builds pkgdown, publishes to GitLab Pages. Pinned to `main`: a hand-started branch pipeline cannot reach it. Strips agent instruction files first, see below |
| `codemeta` | manual, artifact-only (see below) |
| `osv-audit`, `security-audit` | weekly pipeline schedule; manual; and on `main` when their inputs change |

Five things about it are non-obvious enough to be worth stating:

- **The `pages` job deletes files before it builds.** It strips the agent instruction files first — pkgdown renders every top-level `.md`, so `AGENTS.md`, `CLAUDE.md` and the `FP_*.md` files were being published next to the function reference as `AGENTS.html`, `CLAUDE.html` and friends: internal working notes served as if they were user documentation (SEOR-pibdjanz). The job removes them with a glob, `rm -f AGENTS*.md CLAUDE*.md FP_*.md`, immediately before `build_site`, so a file later added under one of those names is covered without another round of this. Add an agent file that does **not** match those patterns and you must extend the glob in the same commit.

- **Pandoc is pinned, and the pin is load-bearing.** The `readme` job asserts
  that `README.md` is byte-identical to a fresh knit of `README.Rmd`, and
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

### Project settings CI depends on, which are not in this repository

These live in GitLab's project settings, so a fresh clone does not carry them
and a `git diff` will never show them missing:

- **Pipeline schedule** (Build > Pipeline schedules): "Weekly dependency
  vulnerability audits", `17 4 * * 1` UTC on `main`. `osv-audit` and
  `security-audit` key off `CI_PIPELINE_SOURCE == "schedule"` directly, so this
  schedule is the only thing that runs them automatically; without it they run
  only on demand. Because the guard is the pipeline source rather than a
  variable, adding a *second* schedule for some other purpose would also fire
  the audits — add a guard variable to both jobs if that ever happens.
- **`OSSINDEX_USER` / `OSSINDEX_TOKEN`** (Settings > CI/CD > Variables, masked):
  Sonatype OSS Index credentials. These were GitHub repository secrets and did
  not follow the move. Until they are re-added, `test-security.R` skips cleanly
  and `security-audit` passes green **without auditing anything** — a silent
  pass, so check the job log rather than the badge.
- **`pages_access_level: public`** (Settings > General > Visibility): required
  for the `pages` job's output to be reachable by anyone but a member.

## Dependency and license scanning

FOSSA and Socket scan this repository's dependencies. On the **free FOSSA
plan the policy rule columns are view-only** — licenses cannot be batch-approved and custom policies cannot be
created or cloned — so there is no `.fossa.yml` and no policy-level fix. The
only lever is per-issue triage in the FOSSA admin panel (ignore + note), which
persists server-side across scans.

Triage rule when a license flag fires:

- **GPL / LGPL / MPL**, any version — including `GPL-2.0-or-later` for Rcpp and
  `GPL-3.0-only` for knitr/rmarkdown — **ignore with a note**. These are
  GPL-compatible with this package's MIT licence, the source is already
  published on CRAN and GitLab, so the copyleft source-disclosure obligation is
  already satisfied. This is standard CRAN practice.
- **AGPL or proprietary — stop and evaluate.** AGPL closes the SaaS loophole and
  is the one copyleft that can actually bite. No current dependency is AGPL.

The dependency surface is tiny and stable (Rcpp is the only linked dependency;
knitr, rmarkdown and testthat are dev-only `Suggests`), so new flags should only
appear when a new dependency is added or an existing one relicenses.

## CRAN release checklist

Follow these steps in order for every CRAN release. The first three and the
fast-forward are the ones we have missed before — skipping them leaves
`NEWS.md`, the published version, and `main` out of sync.

1. **Rename the NEWS heading.** Change the top `# punycoder (development version)`
   heading to the release version (e.g. `# punycoder 1.2.0`) and fold any items
   currently under it into that section. The `news-version` CI check enforces
   that the top NEWS heading is either `(development version)` or the
   `DESCRIPTION` Version.
2. **Set the release version** in `DESCRIPTION` (drop the `.9000` dev suffix).
3. Update `cran-comments.md` for this submission.
4. Run `R CMD build . && R CMD check --as-cran punycoder_*.tar.gz` clean; confirm
   the `full-check` and `sanitizers` jobs are green (run both from
   **Build > Pipelines > Run pipeline** on GitLab, or push the release tag,
   which triggers `full-check` automatically).

   **Cross-platform coverage is not in CI any more.** The GitLab side is a
   Linux R-version matrix only; macOS and Windows checking left with GitHub
   Actions and has no GitLab equivalent on this plan. Use R's own
   forge-independent pre-submission services instead, and do it before every
   submission, not only when something looks suspect:

   - Windows: `devtools::check_win_devel()` (also `check_win_release()`).
   - macOS: upload the tarball to <https://mac.r-project.org/macbuilder/submit.html>.

   Both mail the result back; neither needs an account. These are the services
   CRAN's own incoming checks mirror, so a green result there is closer to the
   real gate than the old matrix was.
5. Submit to CRAN. Once accepted, **tag the released commit** (`git tag -a vX.Y.Z`)
   and push the tag.
6. **Fast-forward `main` to the released/tagged commit** so the default branch
   always reflects what shipped (`git merge --ff-only vX.Y.Z && git push`).
   Verify: `git merge-base vX.Y.Z main` equals the tag.
7. Create the GitLab Release from the tag
   (<https://gitlab.com/bart-turczynski/punycoder/-/releases/new>), using the
   NEWS.md section for that version as the release notes.
8. Open a post-release merge request that bumps `DESCRIPTION` to the next
   `.9000` dev version and adds a fresh `# punycoder (development version)`
   NEWS heading.
9. Sanity check: diff the published CRAN tarball
   (`cran.r-project.org/src/contrib/punycoder_X.Y.Z.tar.gz`) against the tag —
   only CRAN's auto-added `DESCRIPTION` fields should differ.

### Cadence: the calendar gates the ship date, not the code

CRAN policy is *"no more than every 1–2 months seems appropriate"*, so the next
submission window opens roughly a month after the last accepted version, however
ready the code is. Two consequences worth internalizing:

- **Landing behavior changes on `main` early costs nothing.** Only the CRAN
  submission is irreversible; merging early avoids rebase drift on a fast-moving
  branch. Do not hold work back to match a release date.
- **When a release is already breaking, bundle further behavior changes into
  it.** Users must read that release's NEWS anyway, and bundling avoids a second
  release where behavior shifts under them.

While the dev version carries a `.9000` suffix, `R CMD check --as-cran` reports
a standing 2-part NOTE — `Days since last update: N` and `Version contains large
components` — which is expected, not a defect.

### Check the reverse dependencies before assuming a coupled release

The CRAN reverse imports are `pslr` and `rurl`. Before concluding that a change
forces an ordered, coupled release, **verify the revdeps actually call the
function that changed.** The 2026-06 train was real — punycoder 1.2.0 dropped
`host_normalize()`'s inert `strict` argument while published `pslr` was calling
`host_normalize(strict = TRUE)`, so `pslr` had to be fixed on CRAN first or
1.2.0's revdep check would have broken it. The predicate-contract change
(PUNY-cewysjxi) looked similar and was not: neither revdep called `is_punycode`
or `is_idn` at all, so no ordering constraint existed.
