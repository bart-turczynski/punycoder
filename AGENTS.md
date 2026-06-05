# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project

`punycoder` is an R package providing RFC 3492-compliant Punycode/IDN encode/decode functions, implemented in C++ via Rcpp. The package optionally links against `libidn2` when present at build time; otherwise it uses an in-tree fallback algorithm.

## Common commands

All commands run from the package root.

- Build native code & install for dev: `R CMD INSTALL .` (runs `./configure`, which generates `src/Makevars` from `src/Makevars.in` by detecting `libidn2` via `pkg-config`).
- Regenerate Rcpp glue after touching `// [[Rcpp::export]]` attributes: `Rscript -e 'Rcpp::compileAttributes()'`. This rewrites `src/RcppExports.cpp` and `R/RcppExports.R` — commit both.
- Regenerate Rd man pages after editing roxygen blocks: `Rscript -e 'roxygen2::roxygenise()'`.
- Run full test suite: `Rscript -e 'devtools::test()'` (or `R CMD check` for a CRAN-style check).
- Run a single test file: `Rscript -e 'devtools::test(filter = "backends")'` (matches `tests/testthat/test-backends.R`; substitute the suffix).
- Full release check: `R CMD build . && R CMD check --as-cran punycoder_*.tar.gz`.
- Reset the configure artifact: `./cleanup` (removes generated `src/Makevars`).

The `libidn2` backend is optional. On macOS: `brew install libidn2 pkg-config`. The fallback C++ path covers the same surface; `./configure` prints which backend was selected.

## Architecture

### R surface → C++ core

`R/*.R` is a thin wrapper layer. Each exported function (`puny_encode`, `puny_decode`, `url_encode`, `url_decode`, `parse_url`, `validate_domain`, `is_punycode`, `is_idn`) validates its inputs in R (`R/helpers.R::.call_with_validation`), then dispatches to a `*_cpp` shim in `R/RcppExports.R`. The shims call into `src/exports.cpp`, which is the only file that talks to Rcpp types — everything below it uses `std::string` / `std::vector` and lives in `namespace punycoder`.

### Native subsystem split (`src/`)

All declarations live in `src/punycoder_core.h`. Implementations are split by responsibility — keep new logic in the matching file rather than spreading concerns:

- `punycoder_algorithm.cpp` — RFC 3492 reference encoder/decoder (fallback).
- `punycoder_backend.cpp` — Backend selection (`select_label_backend`) and the `libidn2` adapter guarded by `#ifdef PUNYCODER_USE_LIBIDN2`. **All `#ifdef PUNYCODER_USE_LIBIDN2` should stay in this file**; don't sprinkle them through domain/URL code (per CONTRIBUTING.md).
- `punycoder_utf8.cpp` — UTF-8 ↔ codepoint conversion and ASCII helpers.
- `punycoder_domain.cpp` — `validate_and_parse_domain`, label-level rules (length, hyphens, xn-- detection).
- `punycoder_url.cpp` — `parse_url_string`, host classification (DNS / IPv4 / IPv6), URL rebuild with a substituted host.
- `punycoder_service.cpp` — `PunycodeService` facade that wires the chosen backend to the domain/URL layers and applies the `strict` flag.
- `punycoder_errors.cpp` — `PunycoderError` and the canonical `throw_error(ErrorCode, …)` map. **R-facing error message prefixes are part of the contract** (per CONTRIBUTING.md) — `exports.cpp` adds prefixes like `"Error encoding domain: …"`. Don't change those strings without bumping tests.
- `exports.cpp` — Rcpp boundary: NA handling, strict-vs-non-strict error policy (strict → `Rcpp::stop`; non-strict → return `NA_character_`), and the `compare_backends_cpp` / `backend_info_cpp` introspection used by tests.

### Backend selection

`select_label_backend(BackendPreference)` returns a `LabelBackend` (a pair of encode/decode function pointers plus a name). `automatic` resolves to `"libidn2+fallback"` when libidn2 is compiled in (with libidn2 tried first, fallback on exception), `"libidn2"` to force native, `"fallback"` to force the in-tree algorithm. Tests in `tests/testthat/test-backends.R` use `punycoder:::.compare_backends()` (which calls `compare_backends_cpp`) to assert the two backends agree on RFC 3492 vectors (`inst/testdata/rfc3492_vectors.csv`) and on representative URLs; tests `skip_if` when libidn2 isn't available.

Note the libidn2 path is Unix-only: `configure` defines `-DPUNYCODER_USE_LIBIDN2` only on Linux/macOS. `src/Makevars.win` never sets it, so **Windows builds always use the fallback backend** regardless of installed libraries.

### Strict vs non-strict

Every public encode/decode function takes `strict = getOption("punycoder.strict", TRUE)`. The default is set in `R/zzz.R::.onLoad`. In strict mode the C++ layer throws and `exports.cpp` converts to `Rcpp::stop`; in non-strict mode failures become `NA_character_` per element. `puny_encode`/`puny_decode` additionally reject URL-shaped input via `looks_like_url_input()` so callers don't accidentally pass a full URL to a domain-only function.

### Tests

`tests/testthat/` is grouped by concern: `test-encoding`, `test-urls`, `test-validators`, `test-unicode`, `test-rfc3492` (golden vectors), `test-backends` (libidn2 vs fallback parity), `test-contracts` (NA/error policy), `test-internals`, `test-lifecycle`, `test-performance`. Add tests under the matching file for any user-visible change (per CONTRIBUTING.md).

## Repo conventions

- `dev/` holds off-CRAN planning and development notes (e.g. `dev/user_story.md`). It's excluded from the package build via `.Rbuildignore`; put any new dev-only docs here rather than at repo root.
- `AGENTS.md`, `CONTRIBUTING.md`, `THIRD_PARTY_NOTICES.md`, `README.Rmd`, and generated artifacts (`*.Rcheck`, `*.tar.gz`, `*coverage.html`, `lib/`, `README.html`) are all `.Rbuildignore`d — never commit a coverage HTML or a built `.tar.gz`.
