# Architecture

This document is the map of how `punycoder` is built: the layers a call
passes through, where each responsibility lives, and how the build and
data pipelines fit together. It is written for a developer (human or
agent) picking the package up cold.

Companion documents, each owning a different slice:

- **[AGENTS.md](https://bart-turczynski.github.io/punycoder/AGENTS.md)**
  — the terse, always-loaded working contract: conventions, commands,
  hard rules. Kept authoritative; this file expands on the *shape* of
  the system, it does not restate those rules.
- **[DECISIONS.md](https://bart-turczynski.github.io/punycoder/DECISIONS.md)**
  — the *why*: an ADR log of the load-bearing choices (scope, profile,
  backend model, error policy, deprecations).
- **[dev/normalization-contract.md](https://bart-turczynski.github.io/punycoder/dev/normalization-contract.md)**
  — the deep normative spec for
  [`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
  (profile parameters, algorithm, backend parity, versioning). The
  single source of truth for normalization behavior.

## What the package is

`punycoder` is an RFC 3492-compliant Punycode/IDN codec plus a UTS \#46
canonical host normalizer, implemented in C++ via Rcpp. It is the
Punycode/IDNA engine for the sibling packages `pslr` (public-suffix) and
`rurl` (URL parsing). Its scope is deliberately narrow — a
resolvability- and safety-agnostic IDNA primitive; see
[DECISIONS.md](https://bart-turczynski.github.io/punycoder/DECISIONS.md)
ADR-001 and the README “Non-goals” section.

It exposes three concerns:

| Surface | Functions | What it does |
|----|----|----|
| Punycode codec | [`puny_encode()`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md), [`puny_decode()`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md) | Raw RFC 3492 transform with `xn--` framing + LDH checks. **No** Unicode normalization. |
| Host normalization | [`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md), [`normalization_profile_info()`](https://bart-turczynski.github.io/punycoder/reference/normalization_profile_info.md) | UTS \#46 non-transitional canonical host form (mapping + NFC + validation + Punycode). |
| Validators | [`is_punycode()`](https://bart-turczynski.github.io/punycoder/reference/is_punycode.md), [`is_idn()`](https://bart-turczynski.github.io/punycoder/reference/is_idn.md), [`validate_domain()`](https://bart-turczynski.github.io/punycoder/reference/validate_domain.md) | Predicate/validation helpers. |

## Layering

Every call crosses the same four layers, top to bottom. The rule of
thumb: **the lower you go, the fewer types you may use.** Only one file
touches Rcpp; only R files touch R semantics.

    ┌──────────────────────────────────────────────────────────────────┐
    │ R wrapper layer  (R/*.R)                                           │
    │   Input validation, NA policy, strict/non-strict option,          │
    │   S3 print/summary.                                                │
    │   punycoder.R · normalize.R · validators.R ·                      │
    │   results.R · helpers.R · zzz.R                                    │
    └───────────────┬────────────────────────────────────────────────────┘
                    │ .call_with_validation()  →  *_cpp shims
    ┌───────────────▼────────────────────────────────────────────────────┐
    │ Rcpp glue  (R/RcppExports.R  ↔  src/RcppExports.cpp)  — GENERATED   │
    │   Rcpp::compileAttributes(); never hand-edited.                    │
    └───────────────┬────────────────────────────────────────────────────┘
                    │
    ┌───────────────▼────────────────────────────────────────────────────┐
    │ Rcpp boundary  (src/exports.cpp)  — the ONLY file that talks Rcpp   │
    │   NA handling · strict→Rcpp::stop / non-strict→NA_character_ ·      │
    │   R-facing error prefixes · compare_backends / backend_info.       │
    └───────────────┬────────────────────────────────────────────────────┘
                    │ std::string / std::vector only, below this line
    ┌───────────────▼────────────────────────────────────────────────────┐
    │ Core  (namespace punycoder, src/*.cpp + punycoder_core.h)           │
    │   service → domain/normalize → backend → algorithm/nfc/utf8 →       │
    │   vendored Unicode tables.                                          │
    └──────────────────────────────────────────────────────────────────┘

All declarations for the core live in a single header,
`src/punycoder_core.h`; implementations are split by responsibility
across `src/*.cpp`. Editing that header (especially the `ErrorCode`
enum) requires a **clean rebuild** — R’s build does not track header
dependencies, so stale `.o` files cause silent ABI skew. See ADR-009.

## Module map

### R wrapper layer (`R/`)

| File | Responsibility |
|----|----|
| `punycoder.R` | `puny_*` surface + validators exports. |
| `normalize.R` | [`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md) + [`normalization_profile_info()`](https://bart-turczynski.github.io/punycoder/reference/normalization_profile_info.md). |
| `validators.R` | [`is_punycode()`](https://bart-turczynski.github.io/punycoder/reference/is_punycode.md), [`is_idn()`](https://bart-turczynski.github.io/punycoder/reference/is_idn.md), [`validate_domain()`](https://bart-turczynski.github.io/punycoder/reference/validate_domain.md). |
| `results.R` | S3 `print`/summary for `punycoder_validation`. |
| `helpers.R` | Input assertions + `.call_with_validation()` dispatch. |
| `zzz.R` | `.onLoad` option defaults (`punycoder.strict`). |
| `RcppExports.R` | **Generated** shims — do not edit. |

### Native core (`src/`)

| File | Responsibility |
|----|----|
| `punycoder_core.h` | All core declarations (single header). |
| `exports.cpp` | Rcpp boundary: NA/strict policy, error prefixes, introspection. |
| `punycoder_service.cpp` | `PunycodeService` facade wiring backend → domain layer, applies `strict`. |
| `punycoder_domain.cpp` | `validate_and_parse_domain`, label rules (length, hyphens, `xn--`). |
| `punycoder_normalize.cpp` / `.h` | `host_normalize_one`: the UTS \#46 pipeline. |
| `punycoder_nfc.cpp` / `.h` | Unicode NFC (UAX \#15) used by the normalizer. |
| `punycoder_backend.cpp` | `select_label_backend` + the `libidn2` adapter (all `#ifdef PUNYCODER_USE_LIBIDN2` live here). |
| `punycoder_algorithm.cpp` | RFC 3492 reference encoder/decoder (fallback). |
| `punycoder_utf8.cpp` | UTF-8 ↔︎ codepoint conversion + ASCII helpers. |
| `punycoder_errors.cpp` | `PunycoderError` + the `throw_error(ErrorCode, …)` map. |
| `unicode_tables_16_0_0.cpp` / `.h` | **Generated** vendored Unicode 16.0.0 data. |
| `init.c`, `RcppExports.cpp` | C entry points / **generated** Rcpp glue. |

## Request lifecycles

### `puny_encode("café.com")` (codec surface)

1.  [`puny_encode()`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md) (R)
    validates the input is character, non-URL-shaped
    (`looks_like_url_input()` rejects full URLs with an actionable
    error), and reads `strict`.
2.  Dispatch through `.call_with_validation()` → `puny_encode_cpp` shim
    → `exports.cpp`.
3.  `exports.cpp` calls `PunycodeService`, which splits labels and hands
    each to the selected `LabelBackend` for the RFC 3492 transform
    (`xn--` framing added at the domain layer).
4.  On failure: strict → `Rcpp::stop` with a contract prefix; non-strict
    → `NA_character_` for that element.

The codec does **no** Unicode normalization — that is
[`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)’s
job.

### `host_normalize("München.de")` (normalization surface)

Always in-tree, always backend-independent for accept/reject and output
(ADR-003):

1.  [`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md) (R)
    validates the three logical flags and passes the vector down; **it
    never reads `punycoder.strict`** and never aborts on invalid data.
2.  `host_normalize_one` (C++) runs the UTS \#46 pipeline per element:
    terminal-dot capture → map (case fold / map / disallow) → NFC →
    label split → per-label validation + A-label canonical check →
    Punycode-encode non-ASCII labels → DNS length verification →
    reassemble.
3.  Invalid data → `NA` for that element (never throws). Programming
    errors (wrong type) do abort.

The full normative algorithm and worked examples are in
[dev/normalization-contract.md](https://bart-turczynski.github.io/punycoder/dev/normalization-contract.md).

## Backend selection

`select_label_backend(BackendPreference)` returns a `LabelBackend`
(encode/decode function pointers + a name):

- `automatic` → `"libidn2+fallback"` when libidn2 is compiled in
  (libidn2 first, fallback on exception); otherwise `"fallback"`.
- `"libidn2"` forces native; `"fallback"` forces the in-tree algorithm.

libidn2 is a **Punycode accelerator only**, never the IDNA engine —
normalization is always in-tree, so behavior is identical with or
without it (ADR-003). The libidn2 path is **Unix-only**: `configure`
defines `-DPUNYCODER_USE_LIBIDN2` only on Linux/macOS;
`src/Makevars.win` never sets it, so **Windows always uses the fallback
backend**.

Parity between backends is asserted by `tests/testthat/test-backends.R`
via `punycoder:::.compare_backends()` over the RFC 3492 vectors and
representative multi-script domains; those tests `skip_if` libidn2 is
unavailable.

## Build system

    ./configure                         # detects libidn2 via pkg-config
       └─ generates src/Makevars from src/Makevars.in
            ├─ libidn2 found  → -DPUNYCODER_USE_LIBIDN2 + link flags (Unix)
            └─ not found      → in-tree fallback only
    src/Makevars.win                    # Windows: fallback only, never sets the flag
    ./cleanup                           # removes generated src/Makevars

`R CMD INSTALL .` runs `./configure`, which prints the selected backend.
After touching `// [[Rcpp::export]]` attributes, regenerate glue with
`Rscript -e 'Rcpp::compileAttributes()'` (rewrites
`src/RcppExports.cpp` + `R/RcppExports.R`; commit both). After editing
roxygen blocks, run `Rscript -e 'roxygen2::roxygenise()'`.

## Unicode data pipeline

    data-raw/generate_unicode_tables.R      # network access happens ONLY here
       ├─ downloads UCD files (cached under git-ignored data-raw/.ucd-cache/)
       └─ writes src/unicode_tables_16_0_0.{h,cpp}   ← committed, generated
    runtime / build                          # NEVER downloads anything

Normalization depends on this vendored data (combining class,
decompositions, composition, UTS \#46 mapping/status, combining-mark
set, `Bidi_Class`, `Joining_Type`). It is pinned to **one Unicode
version per release** (currently 16.0.0). Bumping the version is a
deliberate, reviewed behavior change — see ADR-004 and
`dev/normalization-contract.md` §8.

## Test taxonomy (`tests/testthat/`)

Grouped by concern; add tests to the matching file for any user-visible
change:

| File | Covers |
|----|----|
| `test-encoding` | `puny_*` codec behavior. |
| `test-rfc3492` | RFC 3492 golden vectors (`inst/testdata/rfc3492_vectors.csv`). |
| `test-backends` | libidn2 vs fallback parity. |
| `test-normalize` | `host_normalize` behavior + profile flags. |
| `test-idna-conformance` | UTS \#46 conformance vectors (`IdnaTestV2.txt`). |
| `test-validators` | Predicate/validation helpers. |
| `test-contracts` | NA / error policy (strict vs non-strict). |
| `test-unicode`, `test-internals`, `test-lifecycle`, `test-performance` | Supporting coverage. |

## Where to add what

- **New host/IDNA behavior** → `host_normalize` / `puny_*`. URL parsing
  belongs upstack in `rurl`; punycoder no longer carries a URL surface
  (ADR-006).
- **New error condition** → add an `ErrorCode` + `throw_error` mapping
  in `punycoder_errors.cpp`; R-facing prefixes are contract (ADR-007).
  Clean rebuild after editing the enum (ADR-009).
- **Backend-specific code** → `punycoder_backend.cpp` only; never
  sprinkle `#ifdef PUNYCODER_USE_LIBIDN2` through domain code (ADR-008).
- **Unicode version bump** → `data-raw/generate_unicode_tables.R`,
  regenerate, bump the pinned version in
  [`normalization_profile_info()`](https://bart-turczynski.github.io/punycoder/reference/normalization_profile_info.md),
  follow `dev/normalization-contract.md` §8.
