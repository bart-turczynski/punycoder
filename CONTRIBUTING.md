# Contributing

## Workflow

- Open an issue or discussion before large behavioral changes.
- Add or update tests for every user-visible change.
- Keep exported function signatures and object shapes stable unless the
  change is explicitly planned as breaking.
- Prefer small, reviewable patches over broad rewrites without coverage.

## Native Code

- The C++ implementation is split by subsystem under `src/`.
- Keep backend-specific logic inside the backend adapter layer rather
  than spreading `#ifdef` checks through domain or URL code.
- Preserve current R-facing error prefixes when changing internal error
  handling.

## Validation

- Run `testthat` locally when a compile toolchain is available.
- For packaging changes, run `R CMD check --as-cran` before release
  work.

## CRAN release checklist

Follow these steps in order for every CRAN release. The first three and
the fast-forward are the ones we have missed before — skipping them
leaves `NEWS.md`, the published version, and `main` out of sync.

1.  **Rename the NEWS heading.** Change the top
    `# punycoder (development version)` heading to the release version
    (e.g. `# punycoder 1.2.0`) and fold any items currently under it
    into that section. The `news-version` CI check enforces that the top
    NEWS heading is either `(development version)` or the `DESCRIPTION`
    Version.
2.  **Set the release version** in `DESCRIPTION` (drop the `.9000` dev
    suffix).
3.  Update `cran-comments.md` for this submission.
4.  Run `R CMD build . && R CMD check --as-cran punycoder_*.tar.gz`
    clean; confirm the platform CI (`R-CMD-check`, R-hub) is green.
5.  Submit to CRAN. Once accepted, **tag the released commit**
    (`git tag -a vX.Y.Z`) and push the tag.
6.  **Fast-forward `main` to the released/tagged commit** so the default
    branch always reflects what shipped
    (`git merge --ff-only vX.Y.Z && git push`). Verify:
    `git merge-base vX.Y.Z main` equals the tag.
7.  Create the GitHub Release from the tag.
8.  Open a post-release PR that bumps `DESCRIPTION` to the next `.9000`
    dev version and adds a fresh `# punycoder (development version)`
    NEWS heading.
9.  Sanity check: diff the published CRAN tarball
    (`cran.r-project.org/src/contrib/punycoder_X.Y.Z.tar.gz`) against
    the tag — only CRAN’s auto-added `DESCRIPTION` fields should differ.
