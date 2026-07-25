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

### Stale objects: clean-rebuild before you trust a build

Leftover `src/*.o` files silently corrupt builds in two different ways. Before benchmarking, before profiling, and after any header edit, clear the objects and reinstall:

```sh
/bin/sh -c 'rm -f src/*.o; R CMD INSTALL .'
```

**Run it through `/bin/sh -c` exactly as written, and do not "simplify" it back to a bare `rm -f src/*.o && R CMD INSTALL .`.** In fish — the maintainer's shell — an unmatched glob is a hard error, not a silent no-op: when `src/` is already clean, `src/*.o` matches nothing, fish aborts with `no matches found: src/*.o`, and the rest of the `&&` chain never runs. The build or benchmark you thought you ran did not run. Wrapping in `/bin/sh -c` also lets `;` replace `&&`, so an already-clean `src/` is not treated as a failure.

- **`-O0` contamination.** `devtools::test()` and `devtools::load_all()` compile via `pkgbuild::compile_dll()`, whose debug flags are `-UNDEBUG -Wall -pedantic -g -O0`. Those unoptimized objects stay in `src/`. A later `R CMD INSTALL .` recompiles only the sources whose `.cpp` changed and links the leftover `-O0` objects into the installed package — measured ~5x slower `host_normalize`, with no warning anywhere.
- **Header staleness.** R's generated `Makevars` tracks `.cpp` mtimes, not header dependencies. Editing a header (especially the `ErrorCode` enum in `src/punycoder_core.h`) leaves objects compiled against the old declarations, producing silent ABI skew rather than a compile error.

Corollary for performance work: **any timing taken without a clean rebuild is meaningless**, and so is any timing taken under `devtools::test()` (which always runs `-O0`). Benchmark against a clean `R CMD INSTALL`, and confirm the compile lines actually show the flags you expect. `tests/testthat/test-performance.R` is deliberately a loose smoke check for this reason — see the note at the top of that file.

## Architecture

### R surface → C++ core

`R/*.R` is a thin wrapper layer. Exported functions are `puny_encode`, `puny_decode`, `host_normalize`, `normalization_profile_info`, `unicode_versions`, `validate_domain`, `is_punycode`, `is_idn`. Each validates its inputs in R (`R/helpers.R::.call_with_validation`), then dispatches to a `*_cpp` shim in `R/RcppExports.R`. The shims call into `src/exports.cpp`, which is the only file that talks to Rcpp types — everything below it uses `std::string` / `std::vector` and lives in `namespace punycoder`.

The wrapper layer is split by concern: `R/punycoder.R` (puny_*/validators surface), `R/normalize.R` (`host_normalize` + `normalization_profile_info`), `R/validators.R`, `R/results.R` (S3 `print`/summary methods for `punycoder_validation`), `R/helpers.R` (input assertions + validation dispatch), `R/zzz.R` (`.onLoad` option defaults).

There is **no URL surface**: the former `url_encode`/`url_decode`/`parse_url` helpers were best-effort host extraction (never an RFC 3986 / WHATWG parser), deprecated in 1.2.0 and removed the following release. New host work goes through `host_normalize` or `puny_*`; URL parsing/canonicalization belongs upstack in `rurl`. `puny_encode`/`puny_decode` reject URL-shaped input with an actionable error pointing at `rurl::get_host()`.

### Native subsystem split (`src/`)

All declarations live in `src/punycoder_core.h`. Implementations are split by responsibility — keep new logic in the matching file rather than spreading concerns:

- `punycoder_algorithm.cpp` — RFC 3492 reference encoder/decoder (fallback).
- `punycoder_normalize.cpp` / `.h` — `host_normalize_one`: the UTS #46 (non-transitional, STD3) canonical-host pipeline — mapping, label validation, A-label check, Punycode encode, DNS length verification. Returns `{valid, value}` (never throws on invalid *data*; invalid → `valid=false`, surfaced to R as `NA`). Exposes three relaxable flags (`check_hyphens`, `use_std3`, `verify_dns_length`); `CheckBidi`/`CheckJoiners` are always on and deliberately not knobs.
- `punycoder_nfc.cpp` / `.h` — Unicode NFC (canonical decomposition + composition) per UAX #15, used by the normalizer.
- `unicode_tables_16_0_0.cpp` / `.h`, `unicode_tables_17_0_0.cpp` / `.h` — vendored Unicode data (combining class, decompositions, composition, UTS #46 mapping/status, combining-mark set, Bidi_Class, Joining_Type), one self-contained unit per shipped version, each ending in a `struct Tables` facade. **Generated, never hand-edited** — see the Unicode tables section below.
- `punycoder_unicode_version.h` / `.cpp` — **leaf**: the `PUNYCODER_UNICODE_VERSIONS(X)` list, `UnicodeVersion`, `kDefaultUnicodeVersion`, string↔enum helpers. Includes no table header. `unicode_tables_registry.h` resolves the facade column and is included only by the two units that instantiate the pipeline.
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

### The predicate contract (`is_punycode` / `is_idn`)

These two are a **third** contract, distinct from both of the above: they are *total* and *strictly logical*. They never throw, never warn, and never return `NA` — every element gets `TRUE` or `FALSE`, including input that is not well-formed UTF-8, which is `FALSE`. Both predicates share `.detect_valid_utf8()` in `R/helpers.R` so they cannot drift apart. Callers who need to distinguish "not punycode" from "not well-formed text" call `validUTF8()` themselves.

The gate is `enc2utf8()` **then** `validUTF8()`, and both halves are load-bearing — this is the one thing to get right if you touch it. `enc2utf8()` alone cannot detect anything, because it is a no-op on bytes already *marked* UTF-8. `validUTF8()` alone inspects raw bytes, so it would wrongly reject a good string merely *marked* `latin1` — a case that always worked, since R transcodes before matching. Gating on raw bytes regresses `is_idn(latin1 "café.com")` from `TRUE` to `FALSE`; `test-contracts.R` covers exactly that.

Deliberately **not** `NA`, even though `host_normalize` uses `NA` for the same malformed bytes: `host_normalize` returns a *value*, where `NA` is a natural "absent", whereas `NA` from a logical predicate breaks `if (is_punycode(x))`. That reasoning is empirical, not aesthetic — no base R string predicate returns `NA` for ill-formed UTF-8 (`validUTF8()` itself answers `FALSE`), stringi's `stri_detect_*` return logicals while `stri_length()` errors, and no IDNA implementation surveyed in any other language returns a third truth value from a boolean predicate (JS `URL.canParse()` → `false`; Go `x/net/idna` has no predicate at all; ICU uses a separate `UIDNAInfo.errors` bitmask; Rust makes it unrepresentable). Rich failure detail belongs to `validate_domain()`, absent values to `host_normalize()`.

Before PUNY-cewysjxi the two disagreed — `is_punycode` reported `TRUE` for ill-formed bytes while `is_idn` warned and reported `FALSE`. That was never a design decision: `is_punycode` uses TRE, which matches bytewise, and `is_idn` uses PCRE, which validates UTF-8 first. Don't "fix" one engine to match the other; the shared gate is what holds the contract.

### Unicode data tables

Normalization depends on vendored Unicode tables (`src/unicode_tables_<tag>.{h,cpp}`) generated by `data-raw/generate_unicode_tables.R`. **Network access happens only at generation time** — the generated C++ is committed and the package never downloads anything at build or run time. Every output name (filenames, header guard, namespace) derives from the single `unicode_version` string in that script; downloaded UCD files are cached per version under the git-ignored `data-raw/.ucd-cache/<version>/`.

**More than one table set ships at once (ADR-015): 16.0.0 and 17.0.0 are both compiled in.** To add another, set `unicode_version`, run the generator, restore the line to the previous value, re-run it and confirm `git diff src/` is empty for the old files — then add the `#include` to `src/unicode_tables_registry.h` and the `X(...)` row to `PUNYCODER_UNICODE_VERSIONS` in `src/punycoder_unicode_version.h`. Do generation and registration in **one commit**: an unreferenced table object still links into the `.so` (R builds pass no `--gc-sections`), so splitting them costs ~250 KB for nothing. Doing only one of the two edits fails loudly — a missing `X(...)` means the version does not exist, a missing `#include` is a compile error where the facade column expands, and a row without an instantiation is a `-Wswitch` warning plus a link error.

Adding a table set also means vendoring **the conformance corpus Unicode published with it**: `data-raw/fetch_idna_fixtures.R` writes `inst/testdata/IdnaTestV2-<version>.txt` for every shipped version (network at generation time only, per-version cache under the git-ignored `data-raw/.idna-cache/`). `tests/testthat/test-idna-conformance.R` runs once per shipped version against the matching corpus, so a set registered without its corpus is only ever checked against another version's expectations — exactly the gap that shipped in #87. The pinned A4_2 root-dot deviation count is a property of the fixture, not the engine, so it is per-version (16.0.0 → 57, 17.0.0 → 59) and an unlisted version fails rather than skips.

The version is selected **at compile time**: `host_normalize_one()` switches on it once per host and everything past that branch is bound to one table set through the `struct Tables` facade (`nfc<T>`, `Normalizer<T>`). That is not stylistic — a function-pointer or virtual accessor would destroy the inline bounds below. Two non-obvious constraints: facade forwarder bodies must stay **fully qualified** (inside the struct the member name hides the namespace-scope one, so an unqualified body is infinite recursion), and `nfc<T>` must have **external linkage** (an explicit instantiation of an internal-linkage template yields a symbol no other TU can name). Table enums are per version and unrelated types; none may appear in `punycoder_core.h`, `punycoder_normalize.h`, or any struct crossing the dispatch boundary. Trie shapes legitimately differ per version — the UTS-46 mapping trie is block 64 at 16.0.0 and block 128 at 17.0.0 — so never assume a shared block size.

Which table set the public surface uses **by default** is `kDefaultUnicodeVersion` (currently 16.0.0); `normalization_profile_info()` reports it. Moving that pin is a reviewed behavior change (`dev/normalization-contract.md` §8), separate from adding a table set. Callers select another with `host_normalize(unicode_version = )` and discover what is available with `unicode_versions()` (ADR-016); `NULL` means the pin and is the only implicit answer — never "newest", which would change behavior under a caller when a set is added. An unshipped version is an error listing what is available, never a fall back to the pin, because a silent fallback would let a caller record a profile identity describing a normalization that never ran. There is deliberately **no** `getOption()` form: `punycoder.strict` is error *policy*, whereas the Unicode version is profile *identity*, and ambient identity breaks reproducibility keys. `punycoder:::.unicode_version_info()` is the one internal hook left, exposing what each table unit reports about itself for the facade-wiring test.

These tables were 56% of `host_normalize`'s process time before PUNY-zgaqusnu, and 33% of self time on all-non-ASCII input after it; they are 12.8% now. The four accessors that profile hot — combining class, UTS #46 mapping, decomposition, `Bidi_Class` — are **two-stage tries** (`STAGE2[(STAGE1[cp >> SHIFT] << SHIFT) | (cp & MASK)]`): two loads, no branches, O(1) for *every* code point rather than only for ASCII, with identical blocks stored once so the unassigned gaps cost one shared block. The trie subsumes the 128-entry ASCII arrays those tables used to carry; what survives in front of it is the derived *low* bound, where a table has one (U+0300 for combining class, U+00C0 for decomposition), because answering ASCII from a compare still beats answering it from two loads — dropping it cost 3% on all-ASCII input. `is_combining_mark` and `joining_type` are consulted once per *label*, not once per code point, so they keep the `range_lookup` binary search and their bounds test; converting them would add 15–20 KB of permanently cold table for no measurable gain.

Before any of them runs, `nfc()` **quick-checks** its input (PUNY-wfzldcuo, ADR-014): UAX #15 `NFC_Quick_Check` plus a combining-class ordering test, and an already-normalized sequence is returned unchanged instead of being rebuilt. This is worth more than every table optimization put together — 1.19–1.22x across the whole ASCII/non-ASCII range — because nearly all real host text is already in NFC and `host_normalize_one()` used to run the full decompose/reorder/compose pipeline on it regardless. Three things to keep intact if you touch it: `NFC_QC=Maybe` is a **real third value** (the character *may* compose with what precedes it) and must fall through to the full pipeline, never be folded into `Yes`; the combining-class **order** test is separate from the property test and is load-bearing on its own; and `nfc_inert()` is applied inline at the top of the loop, not left to the guards inside `combining_class()`/`nfc_quick_check()`, which sit behind a call. Note that a test for the order half must use marks that are `NFC_QC=Yes` — with `Maybe` marks the property test fires first and the order test is never reached, so the obvious test case guards nothing.

`canonical_compose` is keyed on a *pair*, so it is a trie on the **first** element with a scan over that starter's `(b, c)` run behind it (PUNY-mbzhgbta, ADR-013). Keying on the first element is measured, not assumed: 961 pairs hold 391 distinct `a` but only 72 distinct `b`, so `a`-runs are a median of 1 and a maximum of 19 long where `b`-runs would be 3 and 117 — and it is the `a` side that answers the *reject*. Its `b`-bound (`b` is always a combining character; `a` can be ASCII, smallest U+003C) is now exposed `inline` from the generated header as `composes_as_second()` and applied by `compose_pair()` in `punycoder_nfc.cpp` **before** the call: a call trace showed **87%** of the compositions `nfc()` attempts are answered by that bound, so for those the call was the whole cost. Don't move that check back inside the accessor, and don't hand-write the bound at the call site — call the generated predicate.

**Every one of those constants and arrays is derived in the generator** — including each trie's block size (chosen by building it at every shift and keeping the smallest) and every array's element type — from the same UCD vectors the accessor reads, so a version bump moves them automatically and no fast path can drift from the data. Do not hand-write a boundary into the emitted C++, and do not "simplify" a derived constant to a literal (ADR-011, ADR-012). A derived bound stays correct whatever the data does; what a version bump could break is the *shape choice* — a bounds-tested table growing into ASCII would quietly stop hitting its fast path, a silent perf regression with no wrong answer to reveal it, so the generator asserts the shape and fails loudly instead. Each trie is additionally verified against its source ranges for **all 1,114,112 code points** at generation time, which is a stronger check than any corpus can be. The gate for any change here is still an element-wise `host_normalize` diff over `unique(c(source, to_ascii))` from every vendored corpus — `inst/testdata/IdnaTestV2-<version>.txt`, one per shipped version — across all 8 flag combinations, each corpus normalized at its own `unicode_version`.

### Tests

`tests/testthat/` is grouped by concern: `test-encoding`, `test-validators`, `test-unicode`, `test-rfc3492` (golden vectors), `test-backends` (libidn2 vs fallback parity), `test-contracts` (NA/error policy), `test-normalize` (`host_normalize` behavior + profile flags), `test-idna-conformance` (UTS #46 conformance vectors), `test-internals`, `test-lifecycle`, `test-performance`. Add tests under the matching file for any user-visible change (per CONTRIBUTING.md).

## Repo conventions

- `dev/` holds off-CRAN planning and development notes (e.g. `dev/user_story.md`). It's excluded from the package build via `.Rbuildignore`; put any new dev-only docs here rather than at repo root.
- `AGENTS.md`, `CLAUDE.md`, `FP_CLAUDE.md`, `CONTRIBUTING.md`, `THIRD_PARTY_NOTICES.md`, `README.Rmd`, `_pkgdown.yml`, and generated artifacts (`*.Rcheck`, `*.tar.gz`, `*coverage.html`, `lib/`, `README.html`) are all `.Rbuildignore`d — never commit a coverage HTML or a built `.tar.gz`.
