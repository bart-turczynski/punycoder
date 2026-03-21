# Contributing

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
