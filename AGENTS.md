# AGENTS.md

This file provides guidance to coding agents (Claude Code, Codex, etc.) when working with code in this repository.

## Project

`punycoder` is an R package providing RFC 3492-compliant Punycode/IDN encode/decode functions plus a UTS #46 canonical-host normalizer, implemented in C++ via Rcpp. The Punycode codec optionally links against `libidn2` when present at build time; otherwise it uses an in-tree fallback algorithm. Normalization (NFC + UTS #46) is always in-tree, built on vendored Unicode tables pinned to one Unicode version (currently 16.0.0). It is the Punycode/IDNA engine for the `pslr` and `rurl` packages.

This file is the terse, always-loaded working contract. For the system map (layers, module responsibilities, request lifecycles, build/data pipelines) see [ARCHITECTURE.md](ARCHITECTURE.md); for the *why* behind the load-bearing choices see the ADR log in [DECISIONS.md](DECISIONS.md); for the normative normalization spec see [dev/normalization-contract.md](dev/normalization-contract.md).

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

`R/*.R` is a thin wrapper layer. Exported functions are `puny_encode`, `puny_decode`, `host_normalize`, `normalization_profile_info`, `validate_domain`, `is_punycode`, `is_idn`. Each validates its inputs in R (`R/helpers.R::.call_with_validation`), then dispatches to a `*_cpp` shim in `R/RcppExports.R`. The shims call into `src/exports.cpp`, which is the only file that talks to Rcpp types — everything below it uses `std::string` / `std::vector` and lives in `namespace punycoder`.

The wrapper layer is split by concern: `R/punycoder.R` (puny_*/validators surface), `R/normalize.R` (`host_normalize` + `normalization_profile_info`), `R/validators.R`, `R/results.R` (S3 `print`/summary methods for `punycoder_validation`), `R/helpers.R` (input assertions + validation dispatch), `R/zzz.R` (`.onLoad` option defaults).

There is **no URL surface**: the former `url_encode`/`url_decode`/`parse_url` helpers were best-effort host extraction (never an RFC 3986 / WHATWG parser), deprecated in 1.2.0 and removed the following release. New host work goes through `host_normalize` or `puny_*`; URL parsing/canonicalization belongs upstack in `rurl`. `puny_encode`/`puny_decode` reject URL-shaped input with an actionable error pointing at `rurl::get_host()`.

### Native subsystem split (`src/`)

All declarations live in `src/punycoder_core.h`. Implementations are split by responsibility — keep new logic in the matching file rather than spreading concerns:

- `punycoder_algorithm.cpp` — RFC 3492 reference encoder/decoder (fallback).
- `punycoder_normalize.cpp` / `.h` — `host_normalize_one`: the UTS #46 (non-transitional, STD3) canonical-host pipeline — mapping, label validation, A-label check, Punycode encode, DNS length verification. Returns `{valid, value}` (never throws on invalid *data*; invalid → `valid=false`, surfaced to R as `NA`). Exposes three relaxable flags (`check_hyphens`, `use_std3`, `verify_dns_length`); `CheckBidi`/`CheckJoiners` are always on and deliberately not knobs.
- `punycoder_nfc.cpp` / `.h` — Unicode NFC (canonical decomposition + composition) per UAX #15, used by the normalizer.
- `unicode_tables_16_0_0.cpp` / `.h` — vendored Unicode 16.0.0 data (combining class, decompositions, composition, UTS #46 mapping/status, combining-mark set, Bidi_Class, Joining_Type). **Generated, never hand-edited** — see the Unicode tables section below.
- `punycoder_backend.cpp` — Backend selection (`select_label_backend`) and the `libidn2` adapter guarded by `#ifdef PUNYCODER_USE_LIBIDN2`. **All `#ifdef PUNYCODER_USE_LIBIDN2` should stay in this file**; don't sprinkle them through domain code (per CONTRIBUTING.md).
- `punycoder_utf8.cpp` — UTF-8 ↔ codepoint conversion and ASCII helpers.
- `punycoder_domain.cpp` — `validate_and_parse_domain`, label-level rules (length, hyphens, xn-- detection).
- `punycoder_service.cpp` — `PunycodeService` facade that wires the chosen backend to the domain layer and applies the `strict` flag.
- `punycoder_errors.cpp` — `PunycoderError` and the canonical `throw_error(ErrorCode, …)` map. **R-facing error message prefixes are part of the contract** (per CONTRIBUTING.md) — `exports.cpp` adds prefixes like `"Error encoding domain: …"`. Don't change those strings without bumping tests.
- `exports.cpp` — Rcpp boundary: NA handling, strict-vs-non-strict error policy (strict → `Rcpp::stop`; non-strict → return `NA_character_`), and the `compare_backends_cpp` / `backend_info_cpp` introspection used by tests.

### Backend selection

`select_label_backend(BackendPreference)` returns a `LabelBackend` (a pair of encode/decode function pointers plus a name). `automatic` resolves to `"libidn2+fallback"` when libidn2 is compiled in (with libidn2 tried first, fallback on exception), `"libidn2"` to force native, `"fallback"` to force the in-tree algorithm. Tests in `tests/testthat/test-backends.R` use `punycoder:::.compare_backends()` (which calls `compare_backends_cpp`) to assert the two backends agree on RFC 3492 vectors (`inst/testdata/rfc3492_vectors.csv`) and on representative multi-script domains; tests `skip_if` when libidn2 isn't available.

Note the libidn2 path is Unix-only: `configure` defines `-DPUNYCODER_USE_LIBIDN2` only on Linux/macOS. `src/Makevars.win` never sets it, so **Windows builds always use the fallback backend** regardless of installed libraries.

### Strict vs non-strict

Every public encode/decode function takes `strict = getOption("punycoder.strict", TRUE)`. The default is set in `R/zzz.R::.onLoad`. In strict mode the C++ layer throws and `exports.cpp` converts to `Rcpp::stop`; in non-strict mode failures become `NA_character_` per element. `puny_encode`/`puny_decode` additionally reject URL-shaped input via `looks_like_url_input()` so callers don't accidentally pass a full URL to a domain-only function.

Note `host_normalize` does **not** follow the strict/non-strict switch: it always reports invalid input as `NA` (never aborts), so a caller can layer its own policy. This is a separate contract — UTS #46 compatibility processing, deliberately *not* IDNA2008 / RFC 5891 conformance (it accepts labels IDNA2008 rejects, e.g. `"☕.example"`). The pinned profile is `uts46-nontransitional-std3-v1`; `normalization_profile_info()` returns its machine-readable identity and must stay in sync with the flag combination passed to `host_normalize`.

### Unicode data tables

Normalization depends on vendored Unicode tables (`src/unicode_tables_16_0_0.{h,cpp}`) generated by `data-raw/generate_unicode_tables.R`. **Network access happens only at generation time** — the generated C++ is committed and the package never downloads anything at build or run time. To bump the Unicode version, edit `unicode_version` in that script, re-run `Rscript data-raw/generate_unicode_tables.R`, commit the regenerated tables, and update the pinned version reported by `normalization_profile_info()`. Downloaded UCD files are cached under the git-ignored `data-raw/.ucd-cache/`.

### Tests

`tests/testthat/` is grouped by concern: `test-encoding`, `test-validators`, `test-unicode`, `test-rfc3492` (golden vectors), `test-backends` (libidn2 vs fallback parity), `test-contracts` (NA/error policy), `test-normalize` (`host_normalize` behavior + profile flags), `test-idna-conformance` (UTS #46 conformance vectors), `test-internals`, `test-lifecycle`, `test-performance`. Add tests under the matching file for any user-visible change (per CONTRIBUTING.md).

## Repo conventions

- `dev/` holds off-CRAN planning and development notes (e.g. `dev/user_story.md`). It's excluded from the package build via `.Rbuildignore`; put any new dev-only docs here rather than at repo root.
- `AGENTS.md`, `CLAUDE.md`, `FP_CLAUDE.md`, `CONTRIBUTING.md`, `THIRD_PARTY_NOTICES.md`, `README.Rmd`, `_pkgdown.yml`, and generated artifacts (`*.Rcheck`, `*.tar.gz`, `*coverage.html`, `lib/`, `README.html`) are all `.Rbuildignore`d — never commit a coverage HTML or a built `.tar.gz`.
