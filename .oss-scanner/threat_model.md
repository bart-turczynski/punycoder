# Threat model

## What this project does and where untrusted input enters

`punycoder` is an R package with a C++ core (via Rcpp) for RFC 3492 Punycode
and UTS #46 host normalization. It makes no network connections, reads no
files at run time and handles no credentials. It is the Punycode/IDNA engine
under `pslr` and `rurl`; `rurl` feeds hosts parsed from untrusted URLs into
`host_normalize()`, and `rurl`'s output in turn feeds an SSRF guard (`ssrfr`).
So a host string reaching this package is assumed attacker-controlled.

Exported functions that take untrusted strings (character vectors; each
element may be any byte sequence R can hold, including ill-formed UTF-8 or
strings marked `latin1`/`bytes`; R strings cannot contain NUL):

- `puny_encode(x, strict)`, `puny_decode(x, strict)`: per-label RFC 3492
  codec with `xn--` framing and LDH checks, no Unicode normalization.
- `host_normalize(x, check_hyphens, use_std3, verify_dns_length,
  unicode_version)`: UTS #46 non-transitional mapping, NFC, label
  validation (CheckBidi, CheckJoiners always on), Punycode, DNS length check.
  Returns lowercase ASCII or `NA`; never throws on invalid data. `rurl` calls
  it with all three flags `FALSE` as well as with the defaults, so the relaxed
  paths are reachable from URL input.
- `validate_domain(x, strict)`, `is_punycode(x)`, `is_idn(x)`.
- Internal but callable: `punycoder:::.compare_backends(x, mode)` runs the
  same input through both Punycode backends.

Trusted: the calling R code and the flags and `unicode_version` it passes,
the `punycoder.strict` option, and the generated Unicode tables compiled into
the package.

## Components that matter most / least

Most important (native code parsing untrusted bytes):

- `src/punycoder_utf8.cpp`: UTF-8 decoder (overlong, surrogate, truncation
  checks) and encoder. Every non-ASCII path goes through it.
- `src/punycoder_algorithm.cpp`: in-tree RFC 3492 encoder/decoder. Integer
  overflow guards, the insert loop, the `kMaxLabelLength` (1024 bytes) cap.
- `src/punycoder_normalize.cpp`: the UTS #46 pipeline (`host_normalize_one`):
  terminal-dot capture, mapping, label split, A-label decode and canonical
  re-encode check, CheckBidi, CheckJoiners, DNS length.
- `src/punycoder_nfc.cpp`: NFC (decomposition, canonical ordering by
  insertion sort, composition, quick check).
- `src/punycoder_domain.cpp`, `src/punycoder_service.cpp`: label split,
  per-label length cap, strict canonical A-label check, `looks_like_url_input`.
- `src/punycoder_backend.cpp`: the libidn2 adapter (buffer sizing and retry
  around `idn2_punycode_encode/decode`) and fallback selection.
- `src/exports.cpp`: the Rcpp boundary, NA and error handling.
- `src/unicode_tables_{16,17}_0_0.{h,cpp}`: generated two-stage tries and
  range tables indexed by code point. Out-of-bounds indexing for any code
  point up to U+10FFFF is in scope; the data itself is generated from the UCD.

Less important: the R wrappers in `R/` (input type checks, regex predicates),
S3 print methods in `R/results.R`.

Out of scope: libidn2 and Rcpp themselves (unless this package calls them
unsafely); `data-raw/` (offline generators, not shipped); `scripts/`, CI and
other development tooling; `vignettes/`.

## How to exercise it

The image: source at `/src`, package installed (built with
`-g -O1 -fno-omit-frame-pointer`), Imports and Suggests installed, libidn2
linked so both backends exist, `gdb` and `valgrind` installed, no network.

- Full suite: `Rscript -e 'testthat::test_local("/src")'`. The OSS Index and
  OSV dependency audits (`test-security.R`, `test-osv.R`) skip offline.
- One area: `Rscript -e 'testthat::test_local("/src", filter = "normalize")'`.
- Entry points:
  `Rscript -e 'punycoder::host_normalize("xn--fa-hia.de")'`,
  `Rscript -e 'punycoder::puny_decode("xn--caf-dma.com", strict = FALSE)'`,
  `Rscript -e 'punycoder::host_normalize(x, FALSE, FALSE, FALSE)'` (relaxed),
  `Rscript -e 'punycoder:::.compare_backends("xn--caf-dma", "decode_domain")'`,
  `Rscript -e 'punycoder:::.backend_info()'`.
- Ill-formed bytes: build with `rawToChar(as.raw(c(0x61, 0xed, 0xa0, 0x80)))`
  and `Encoding(x) <- "UTF-8"`, which R does not validate.
- Native debugging:
  `R -d gdb --debugger-args='-batch -ex run -ex bt' --vanilla -e '<expr>'`
  and `R -d 'valgrind --error-exitcode=1' --vanilla -e '<expr>'`.
- Corpora: `inst/testdata/IdnaTestV2-16.0.0.txt` and `-17.0.0.txt` (Unicode
  UTS #46 conformance files, loaded by `tests/testthat/helper-idna.R`) and
  `inst/testdata/rfc3492_vectors.csv`; installed under
  `system.file("testdata", package = "punycoder")`.

## How you rate severity

Rate by what reaches the caller. Strings are untrusted; flags are trusted.

- **Critical**: memory corruption in the native code (out-of-bounds write,
  use-after-free, double free) reachable from an untrusted string through any
  exported function, at default or relaxed flags.
- **High**: any other out-of-bounds read or uninitialized read reachable from
  an untrusted string, even without a demonstrated exploit. A non-`NA`
  `host_normalize()` or `puny_*` result that makes a caller's security decision
  wrong: output that is not the UTS #46 ToASCII result for that input in a way
  that changes the host (an A-label that decodes to a U+002E or other
  separator and is passed through, two backends giving different hosts for
  the same input, a non-canonical A-label accepted as canonical so two
  spellings of one host compare unequal, non-ASCII bytes in output).
- **Medium**: denial of service from small untrusted input: CPU or memory
  superlinear in input length (the codec caps labels at 1024 bytes; check
  what `host_normalize()`'s mapping and NFC passes do with long input or
  long runs of combining marks), or a crash of the R process (segfault,
  abort, uncaught C++ exception), as opposed to an R error.
- **Low**: wrong results with no security consequence, including UTS #46 or
  RFC 3492 nonconformance against the vendored corpora; problems that need
  the caller to pass hostile flags or call internals with crafted arguments.

## Anything to leave alone

Documented design choices, not bugs:

- `puny_*` and `validate_domain()` raise an R error (`Rcpp::stop`) on invalid
  input under `strict = TRUE`, and return `NA` under `strict = FALSE`;
  `host_normalize()` returns `NA` for invalid input; `is_punycode()` and
  `is_idn()` return `FALSE` for ill-formed UTF-8 (ADR-005, AGENTS.md).
- No homograph, confusable, mixed-script or display-safety checks, no URL
  parsing, no PSL or per-TLD rules (ADR-001, README "Non-goals").
- UTS #46 compatibility processing, not IDNA2008: labels such as
  `☕.example` are accepted (ADR-002).
- A single trailing root dot is kept (ADR-010). With
  `verify_dns_length = FALSE` empty labels and over-long hosts are accepted;
  with `use_std3 = FALSE` non-LDH ASCII such as `_` survives. The relaxed flags
  only turn rejections into acceptances; WHATWG forbidden-host-code-point
  checks belong to the caller.
- Non-strict `puny_decode()` decodes non-canonical A-labels (e.g. uppercase
  payloads) on a best-effort basis; strict mode and `host_normalize()` reject
  them.
- Windows builds use only the in-tree backend; libidn2 is a Punycode
  accelerator, never the IDNA engine (ADR-003, ADR-008).

Patches: minimal C++ or R fixes in the package's style (core declarations in
`src/punycoder_core.h`, `#ifdef PUNYCODER_USE_LIBIDN2` only in
`src/punycoder_backend.cpp`, never hand-edit `src/unicode_tables_*` or
`*RcppExports*`; fix the generator in `data-raw/` instead). Add a `testthat`
regression test next to the existing tests for that area
(`tests/testthat/test-normalize.R`, `test-encoding.R`, `test-contracts.R`,
`test-validators.R`, ...). Add a `NEWS.md` entry under `# punycoder (development version)`, citing
the standard and clause (e.g. "UTS #46 section 4.1", "RFC 3492 section 6.2")
when the fix is a conformance fix. A fix that changes what `host_normalize()`
accepts or rejects also increments the profile token's `-vN` revision
(ADR-018, `dev/normalization-contract.md` section 8); say so in the report.
