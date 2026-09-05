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
`.github/workflows/verify.yml` routinely spends 20–30 minutes in
`setup-r-dependencies` on a cold cache). Commit, push, merge.

Still do the cheap things that *are* implicated, because CI checks them:

- re-knit `README.md` when `README.Rmd` changes (the `readme` job checks they
  are in sync);
- run `roxygenise()` and commit `man/` when roxygen blocks change;
- keep `NEWS.md` consistent with the `DESCRIPTION` version (the `news-version`
  workflow checks the top heading).

Anything touching `R/`, `src/`, or `tests/` is not doc-only — run the normal
gate there.

## Dependency and license scanning

FOSSA and Socket scan this repository's dependencies (cited in
`.bestpractices.json`). On the **free FOSSA plan the policy rule columns are
view-only** — licenses cannot be batch-approved and custom policies cannot be
created or cloned — so there is no `.fossa.yml` and no policy-level fix. The
only lever is per-issue triage in the FOSSA admin panel (ignore + note), which
persists server-side across scans.

Triage rule when a license flag fires:

- **GPL / LGPL / MPL**, any version — including `GPL-2.0-or-later` for Rcpp and
  `GPL-3.0-only` for knitr/rmarkdown — **ignore with a note**. These are
  GPL-compatible with this package's MIT licence, the source is already
  published on CRAN and GitHub, so the copyleft source-disclosure obligation is
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
   the platform CI (`R-CMD-check`, R-hub) is green.
5. Submit to CRAN. Once accepted, **tag the released commit** (`git tag -a vX.Y.Z`)
   and push the tag.
6. **Fast-forward `main` to the released/tagged commit** so the default branch
   always reflects what shipped (`git merge --ff-only vX.Y.Z && git push`).
   Verify: `git merge-base vX.Y.Z main` equals the tag.
7. Create the GitHub Release from the tag.
8. Open a post-release PR that bumps `DESCRIPTION` to the next `.9000` dev
   version and adds a fresh `# punycoder (development version)` NEWS heading.
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
