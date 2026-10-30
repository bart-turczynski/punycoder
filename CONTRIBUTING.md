# Contributing

Report bugs and request features in the GitLab issue tracker:
<https://gitlab.com/bart-turczynski/punycoder/-/work_items>. Report security issues
privately as described in `SECURITY.md`. Send changes as merge requests on
GitLab; the GitHub repository is a read-only mirror.

New code needs tests, and each user-facing change needs one `NEWS.md` bullet.
Add or update tests for every user-visible change, keep exported function
signatures and object shapes stable unless the change is explicitly planned
as breaking, and prefer small, reviewable patches over broad rewrites without
coverage. A merge request must pass the verification command below.

Verification is fleet-ci's local gate, which runs in the fleet Docker image
(settings in `.fleet-ci.yml`). Install its pre-push hook once per clone, from
the package root:

```sh
.fleet-ci/pre-push --install
```

From then on the gate runs on every push, on each pushed ref's tip, followed
by the pre-commit pre-push hooks. `pre-commit install -f` (which installs
both hook types, from `.pre-commit-config.yaml`'s
`default_install_hook_types`) and `pre-commit install -f --hook-type
pre-push` replace that hook and drop the gate; re-run
`.fleet-ci/pre-push --install` after either. Without `-f`,
`pre-commit install` keeps the gate (pre-commit's migration mode). To run the
gate by hand on `HEAD`:

```sh
.fleet-ci/gate auto
```

The gate checks the committed tree, never uncommitted edits.

## Orientation

Before making changes, skim [ARCHITECTURE.md](ARCHITECTURE.md) (how the package
is layered and where each responsibility lives, and the rules for native code).
It links the ADR log and the normative normalization spec.

Maintainer notes live in `design/`: CI and the project settings it depends on
in
[`design/ci.md`](https://gitlab.com/bart-turczynski/punycoder/-/blob/main/design/ci.md),
the CRAN release deltas in
[`design/release-deltas.md`](https://gitlab.com/bart-turczynski/punycoder/-/blob/main/design/release-deltas.md),
the linter set in
[`design/lint-set.md`](https://gitlab.com/bart-turczynski/punycoder/-/blob/main/design/lint-set.md),
the issue-first rule for large changes in
[`design/workflow.md`](https://gitlab.com/bart-turczynski/punycoder/-/blob/main/design/workflow.md),
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

## What not to commit

Keep local-only planning state in `_scratch/`. Do not commit `_scratch/`,
`tmp/`, `.fp/`, secrets (`.Renviron`, `.env`), build outputs (`*.Rcheck`,
`*.tar.gz`, `*coverage.html`, `README.html`, `lib/`, `src/*.o`, `docs/`) or
generated caches (`data-raw/.ucd-cache/`, `data-raw/.idna-cache/`).
