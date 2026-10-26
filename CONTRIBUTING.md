# Contributing

Report bugs and request features in the GitLab issue tracker:
<https://gitlab.com/bart-turczynski/punycoder/-/work_items>. Report security issues
privately as described in `SECURITY.md`. Send changes as merge requests on
GitLab; the GitHub repository is a read-only mirror.

New code needs tests, and each user-facing change needs one `NEWS.md` bullet.
A merge request must pass the verification command below.

Run verification (the pre-push chain: the hygiene hooks, citation and
BugReports checks, the toolchain check, the URL check, spelling, then the
docs-drift check, lintr and `R CMD check --as-cran` in the `verify` hook):

```sh
pre-commit run --hook-stage pre-push --all-files
```

In the `verify` hook the docs-drift check judges the commit being pushed (`HEAD`
when run by hand), while lintr and `R CMD check` judge the working tree,
uncommitted edits included.

## Orientation

Before making changes, skim [ARCHITECTURE.md](ARCHITECTURE.md) (how the package
is layered and where each responsibility lives) and [DECISIONS.md](DECISIONS.md)
(the ADR log explaining the load-bearing design choices — scope, normalization
profile, backend model, error policy, deprecations). Normalization behavior is
specified normatively in [dev/normalization-contract.md](dev/normalization-contract.md).

Maintainer notes live in `design/`: CI and the project settings it depends on
in
[`design/ci.md`](https://gitlab.com/bart-turczynski/punycoder/-/blob/main/design/ci.md),
the CRAN release deltas in
[`design/release-deltas.md`](https://gitlab.com/bart-turczynski/punycoder/-/blob/main/design/release-deltas.md),
the linter set in
[`design/lint-set.md`](https://gitlab.com/bart-turczynski/punycoder/-/blob/main/design/lint-set.md),
local validation and the doc-only gate in
[`design/validation.md`](https://gitlab.com/bart-turczynski/punycoder/-/blob/main/design/validation.md),
and dependency and license scanning in
[`design/dependency-scanning.md`](https://gitlab.com/bart-turczynski/punycoder/-/blob/main/design/dependency-scanning.md).

## Development dependencies

Beyond the runtime requirements in the README (R >= 4.1.0, `Rcpp`, and a C++
compiler), development uses `testthat`, `knitr` and `rmarkdown`, all in
`Suggests`. Install `libidn2` and `pkg-config` too, so the native backend is
built and the backend parity tests in `test-backends` run against it.

```sh
Rscript -e 'pak::local_install_deps(dependencies = TRUE)'
```

## Workflow

- Open an issue or discussion before large behavioral changes.
- Add or update tests for every user-visible change.
- Keep exported function signatures and object shapes stable unless the change is explicitly planned as breaking.
- Prefer small, reviewable patches over broad rewrites without coverage.

## Native Code

- The C++ implementation is split by subsystem under `src/`.
- Keep backend-specific logic inside the backend adapter layer rather than spreading `#ifdef` checks through domain or URL code.
- Preserve current R-facing error prefixes when changing internal error handling.

## What not to commit

Keep local-only planning state in `_scratch/`. Do not commit `_scratch/`,
`tmp/`, `.fp/`, secrets (`.Renviron`, `.env`), build outputs (`*.Rcheck`,
`*.tar.gz`, `*coverage.html`, `README.html`, `lib/`, `src/*.o`, `docs/`) or
generated caches (`data-raw/.ucd-cache/`, `data-raw/.idna-cache/`).
