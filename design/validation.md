# Validation

- Run `testthat` locally when a compile toolchain is available.
- For packaging changes, run `R CMD check --as-cran` before release work.
- For performance work, the clean rebuild and the measurement protocol in
  [dev/perf-measurement.md](../dev/perf-measurement.md) are the gate — a timing
  taken without them is not evidence.

## Doc-only changes skip the heavy gate

A change to `.md` / `.Rmd` / vignette prose / roxygen comment blocks cannot
affect the native build, so it does **not** need the clean `rm -f src/*.o`
rebuild, does not need `R CMD build` + `R CMD check --as-cran`, and should not
sit waiting on the slow report-only CI jobs (the `coverage` job in
`.gitlab-ci.yml` routinely spends 20–30 minutes installing dependencies on a
cold cache). Commit, push, merge.

Still do the cheap things that *are* implicated, because CI checks them:

- re-knit `README.md` when `README.Rmd` changes (the `readme` check in the
  `gates` job checks they are in sync);
- run `roxygenise()` and commit `man/` when roxygen blocks change;
- keep `NEWS.md` consistent with the `DESCRIPTION` version (the `news-version`
  check in the `gates` job checks the top heading).

Anything touching `R/`, `src/`, or `tests/` is not doc-only — run the normal
gate there.
