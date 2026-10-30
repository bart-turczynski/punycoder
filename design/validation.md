# Validation

- Run `testthat` locally when a compile toolchain is available.
- For packaging changes, run `R CMD check --as-cran` before release work.
- For performance work, the clean rebuild and the measurement protocol in
  [dev/perf-measurement.md](../dev/perf-measurement.md) are the gate — a timing
  taken without them is not evidence.

## Doc-only changes skip the heavy gate

A change to `.md` / `.Rmd` / vignette prose / roxygen comment blocks cannot
affect the native build, so it does **not** need the clean `rm -f src/*.o`
rebuild or a hand-run `R CMD build` + `R CMD check --as-cran`. Commit, push,
merge. The local gate (`.fleet-ci/gate`) picks its own tier: a diff touching
only `design/**/*.md` (and the like; `_pkgdown.yml` is excluded here) gets the
docs tier, spelling and `pkgdown::check_pkgdown()`; anything else, `README.Rmd`,
vignettes and roxygen included, gets the full tier with one `R CMD check`
(see [ci.md](ci.md)).

Still do the cheap things that *are* implicated, because the full tier checks
them:

- re-knit `README.md` when `README.Rmd` changes (`scripts/check-readme-drift.sh`
  checks they are in sync);
- run `roxygenise()` and commit `man/` when roxygen blocks change
  (`scripts/check-docs-drift.R` checks them);
- keep `NEWS.md` consistent with the `DESCRIPTION` version
  (`scripts/gates-news-version.sh` checks the top heading).

Anything touching `R/`, `src/`, or `tests/` is not doc-only — run the normal
gate there.
