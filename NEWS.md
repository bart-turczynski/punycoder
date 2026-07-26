# punycoder (development version)

## Breaking changes

* **The pinned Unicode version moved from 16.0.0 to 17.0.0, and the profile
  token is now `uts46-nontransitional-std3-v2`.** A call that names no
  `unicode_version` now normalizes against Unicode 17.0.0 data. The change is
  accept-only in practice: across both vendored IdnaTestV2 corpora and all 8
  flag combinations, the new default matches an explicit `"17.0.0"` in all
  102,448 comparisons and differs from `"16.0.0"` on 3 rows (16.0.0 corpus) and
  5 rows (17.0.0 corpus) --- every one of them `NA` becoming a value, with zero
  changed values. Nothing that normalized before stops normalizing.

  The `-v1` → `-v2` bump is deliberate and is the part to act on. The bare token
  means "whatever the pin is", so without the bump one string would have denoted
  16.0.0 before this release and 17.0.0 after. Anything using the token as a
  cache or reproducibility key must re-key: a stale key now misses loudly
  instead of colliding silently. Callers who want the old data can pass
  `unicode_version = "16.0.0"`, which is still shipped and returns identical
  results to 1.2.1 --- their token becomes
  `uts46-nontransitional-std3-v2+unicode-16.0.0`. `pslr` detects the move on its
  own (it compares both `normalization_profile` and `unicode_version`, and
  rebuilds its index on either mismatch), so the effect there is a one-time
  rebuild on load until it reships, not a stale answer.

  This release also fixes the shipped-versions policy: punycoder ships the
  **current and the previous** Unicode version, and a version is deprecated for
  one release cycle --- announced here, still shipped and selectable --- before
  it is dropped (ADR-017).

* The deprecated URL surface --- `url_encode()`, `url_decode()`, and
  `parse_url()` --- has been **removed**, one release after the `.Deprecated()`
  warning cycle introduced in 1.2.0. These were always best-effort host
  extraction/rewriting, never an RFC 3986 / WHATWG URL parser or canonicalizer.
  Use the `rurl` package for URL parsing and canonicalization, or pass the host
  alone to `host_normalize()` / `puny_encode()` / `puny_decode()` for host-only
  needs. `puny_encode()` / `puny_decode()` continue to reject URL-shaped input
  with an actionable error pointing at `rurl::get_host()`. The internal URL
  parser (`punycoder_url.cpp`) and the `punycoder_parsed_url` print method are
  gone with the surface.

* `is_punycode()` and `is_idn()` now agree on input that is not well-formed
  UTF-8, and both report `FALSE` for it. Previously `is_punycode()` reported
  `TRUE` **silently** for such input --- steering callers into `puny_decode()`
  for a string every other function in the package refuses to process --- while
  `is_idn()` warned and reported `FALSE`. The split was not deliberate:
  `is_punycode()` matches with R's default TRE engine, which matches bytewise,
  and `is_idn()` used `perl = TRUE`, where PCRE validates UTF-8 first. Both now
  share one gate, so the spurious `is_idn()` warning is gone too. The predicates
  remain total and strictly logical --- never `NA`, never an error --- so
  `if (is_punycode(x))` is always safe; call `validUTF8(x)` to distinguish "not
  punycode" from "not well-formed text". Answers for well-formed input,
  including strings marked `latin1`, are unchanged.

## New features

* The Unicode table set is now selectable per call.
  `host_normalize(x, unicode_version = )` and
  `normalization_profile_info(unicode_version = )` accept any version this
  build ships, and a new `unicode_versions()` reports what that is (currently
  `"16.0.0"` and `"17.0.0"`). `NULL`, the default, means the pinned version ---
  which this release moves to 17.0.0, see Breaking changes above; `NULL` never
  means "newest", so a later release compiling in another table set will not
  change results underneath a caller. Selecting another version appends
  `+unicode-<version>` to that token, on the same rule as a relaxed flag, so
  two normalizations that genuinely differ can never mint `identical()` tokens.
  Naming a version the build does not ship is an error listing what is
  available, never a silent fall back to the pin --- a fallback would let a
  caller record a profile identity describing a normalization that never ran.
  There is deliberately **no** global option for this: unlike
  `punycoder.strict`, which is an error-policy preference, the Unicode version
  is part of profile identity, and making identity ambient would let the same
  code mint different reproducibility keys in different sessions
  (ADR-016).

* `validate_domain()` results are now readable at scale. `print()` opens with a
  count header (`12 domains: 5 valid, 7 invalid (strict = TRUE)`), stops after
  10 per-domain blocks with a `... and N more` footer instead of dumping one
  block per element, and shows each error's machine-readable code alongside its
  message. A new `summary()` method condenses the whole vector into a data
  frame of `error_code` / `n` sorted by count descending, carrying `n`,
  `n_valid`, `n_invalid`, and `strict` as attributes, so failures across a
  large batch can be tallied programmatically.

## Bug fixes

* `puny_decode()` now rejects malformed A-label input consistently across
  backends. The in-tree fallback decoder previously accepted non
  letter-digit-hyphen (LDH) characters in a label's literal section (e.g.
  `xn--(o)-...`) and echoed an empty Bootstring payload (`xn---`) back unchanged,
  where libidn2 rejected both. It now applies the documented LDH check to decode
  input and reports these as an error under `strict = TRUE` / `NA` under
  `strict = FALSE`, so the two backends agree on every input.

* `puny_encode()`, `puny_decode()`, and `validate_domain()` now transcode
  character input to UTF-8 before dispatching to native code, and Unicode
  output is explicitly marked as UTF-8. Previously only `host_normalize()`
  transcoded, so a Latin-1-marked (or non-UTF-8 native) host reached the UTF-8
  decoder as ill-formed bytes and the same string produced different answers
  depending on how R happened to mark it (#67).

## Performance

* `host_normalize()` no longer normalizes input that is already normalized ---
  **1.22x** on all-ASCII hosts, 1.21x at 20% non-ASCII, 1.22x at 50%, and 1.19x
  when every host is non-ASCII. Unicode NFC ran unconditionally, so a host that
  was already in NFC --- which nearly all real host text is --- paid for a full
  decompose, canonical-reorder and recompose pass to produce a byte-identical
  copy of itself. An all-ASCII host was making 295,792 pointless composition
  attempts per 20,000 hosts. `nfc()` now applies the UAX #15 quick check
  (`NFC_Quick_Check` plus a combining-class ordering test) and returns its input
  untouched when it passes; below U+0300 that costs one comparison per character
  and no table read at all.

  This is the largest single normalizer win in this release, and unlike the
  table work below it helps ASCII input most, because that input was paying the
  most for nothing. Input that genuinely needs normalizing does not regress: on
  a corpus transformed to NFD, so the check always fails, throughput is still
  1.13x/1.07x/1.01x, because the check abandons at the first character that
  fails rather than scanning to the end. `NFC_Quick_Check=Maybe` is treated as a
  real third value and falls through to the full pipeline. Output is unchanged
  on every input in the UTS #46 conformance corpus under all supported flag
  combinations, and `nfc()` was verified against the pipeline it skips over all
  19,965 rows of the official UAX #15 normalization corpus, every single code
  point, and 280 million code-point pairs.

* `host_normalize()` is faster again on non-ASCII hosts --- **1.05x** when every
  host is non-ASCII, 1.04x at 50%, 1.03x at 20%, unchanged on all-ASCII input
  --- with the last Unicode table still on a binary search converted. Canonical
  composition is keyed on a *pair* of code points, so it could not become a trie
  the way the four accessors below did; it is now a trie on the **first** element
  with a short scan over that starter's partners behind it. Keying on the first
  element is measured rather than assumed: the 961 pairs hold 391 distinct first
  elements but only 72 distinct second ones, so the runs to scan are a median of
  1 long instead of 3, and it is the first element that answers the common
  *reject* --- a starter that never composes, such as any CJK ideograph, used to
  walk the whole 961-pair search only to conclude 0. The accessor is 6.1x faster
  on that reject path and 2.5x on a successful composition, and its share of self
  time falls from 5.3% to 1.9%.

  The end-to-end figure is smaller than either of those because most attempted
  compositions never reach the table at all: 87% of them are answered by the
  bound on the second element, since that element is just the next character
  after a starter and ordinary text is not combining marks. That bound is now
  exposed `inline` from the generated header and applied *before* the call
  rather than inside it, which is what makes the ASCII-heavy end of the range
  faster rather than merely unchanged. Output is unchanged on every input in the
  UTS #46 conformance corpus under all supported flag combinations.

* `host_normalize()` is faster on non-ASCII hosts --- **1.25x** when every host
  is non-ASCII, 1.16x at 50%, 1.08x at 20%, and unchanged on all-ASCII input
  --- and the installed shared object is **64 KB smaller**. The four Unicode
  accessors that profiled hot (combining class, UTS #46 mapping, canonical
  decomposition, `Bidi_Class`) no longer binary-search: each is a two-stage
  trie, two loads and no branches, O(1) for every code point rather than only
  for ASCII. The previous release made ASCII free but left every non-ASCII code
  point paying 11-14 branch-mispredicting probes --- and the worst case was not
  an exotic character but a common one the table does not list, since every CJK
  ideograph walked the whole combining-class table only to conclude 0. Table
  lookups fell from 33% of self time to 17% on an all-non-ASCII corpus. Storing
  identical blocks once, and keying the UTS #46 trie on distinct
  (status, mapping) values rather than on ranges, is what makes the structure
  smaller than the range tables it replaced. Every array, element type and
  block size is derived in `data-raw/generate_unicode_tables.R`, which now also
  verifies each trie against its source ranges for all 1,114,112 code points
  before emitting it. Output is unchanged on every input in the UTS #46
  conformance corpus under all supported flag combinations.

* `host_normalize()` is substantially faster again --- **1.75x** on all-ASCII
  hosts, 1.36x on a mixed corpus at 20% non-ASCII, and 1.12x even when every
  host is non-ASCII. Lookups into the vendored Unicode tables were 56% of
  process time: seven near-identical binary searches, ~14 branch-mispredicting
  probes per code point for the 9,185-range UTS #46 table alone. They now share
  one search, and each answers ASCII --- the dominant input --- without
  searching at all, via a 128-entry direct index for the two tables that cover
  ASCII and a bounds test for the rest. Every boundary is derived in
  `data-raw/generate_unicode_tables.R` from the UCD data itself, so it cannot
  drift from the table it guards and a Unicode version bump moves it
  automatically. Output is unchanged on every input in the UTS #46 conformance
  corpus under all supported flag combinations.

* `host_normalize()` is roughly 25-30% faster. Label validation no longer
  re-runs Unicode NFC on labels taken straight from the label split: NFC is
  applied to the whole host before splitting, and U+002E is a safe break point
  (it appears in no canonical decomposition and no composition pair), so those
  labels are already in NFC by construction. Punycode-decoded A-label payloads,
  which never go through that pass, are still checked. Output is unchanged on
  every input in the UTS #46 conformance corpus, under all supported flag
  combinations.

## Internal

* The UTS #46 conformance suite now runs once per shipped Unicode version,
  against the corpus Unicode published with that version. There was a single
  `inst/testdata/IdnaTestV2.txt` of 16.0.0 vintage and one hardcoded expectation
  set, so the 17.0.0 table set added alongside 16.0.0 was only ever checked
  against 16.0.0's expectations --- a corpus that predates it and cannot
  exercise anything 17.0.0 changed. Each version now has its own vendored corpus
  (`inst/testdata/IdnaTestV2-16.0.0.txt`, dated 2024-07-03;
  `inst/testdata/IdnaTestV2-17.0.0.txt`, dated 2025-05-01), named with the
  dotted version exactly as `unicode_versions()` reports it so tests build the
  path with no tag translation. A new `data-raw/fetch_idna_fixtures.R` acquires
  them the way the UCD table generator does: network access at generation time
  only, a per-version cache under a git-ignored `data-raw/.idna-cache/`, and a
  shape check so a truncated download or an HTML error page cannot be committed
  and quietly weaken every conformance assertion. The pinned A4_2 root-dot
  deviation count is a property of the fixture rather than of the engine, so it
  is per-version too (57 at 16.0.0, 59 at 17.0.0, both entirely A4_2 with zero
  false rejections), and a version with no listed count fails loudly instead of
  skipping its check. Added with it is the invariant the multi-version work
  actually rests on, which no fixed delta count can express: a newer table set
  may newly *accept* a host, but must never reject one an older set accepted,
  nor return a different value for one both accept. No package code changed and
  no result moved.

# punycoder 1.2.1

Maintenance release over the 1.2.0 development tag; the public API is unchanged.

## Internal

* Added OSV and OSS Index dependency vulnerability audits, a `goodpractice`-aligned `.lintr`, pre-commit and community-health configuration, and Dependabot for GitHub Actions; no package code or user-facing change (#57, #58, #61, #63).

* More than one generated Unicode table set can now be compiled into the
  package at once, and Unicode 17.0.0 ships alongside 16.0.0. The version is
  bound at **compile** time --- one branch per host at the entry to the
  normalizer, never per code point --- so the inline table bounds the
  normalization pipeline depends on are untouched; benchmarks are flat and the
  conformance output is byte-identical. Normalization behavior is **unchanged**:
  the pinned profile still uses Unicode 16.0.0, and reaching another table set
  is possible only through internal test hooks. The second table set does grow
  the installed shared object by roughly 250 KB (#84, #85, #87; ADR-015).

# punycoder 1.2.0

## Breaking changes

* `host_normalize()` no longer takes a `strict` argument. It was inert (always
  applied the full profile) and reserved for exactly this relaxed variant, which
  the three explicit flags below now provide.

## New features

* `host_normalize()` gains three UTS #46 processing flags --- `check_hyphens`,
  `use_std3`, and `verify_dns_length` --- each defaulting to `TRUE` (the strict
  `uts46-nontransitional-std3-v1` profile) and each independently relaxable.
  These are standard UTS #46 parameters, not a browser mode: `CheckBidi` and
  `CheckJoiners` always apply, and full WHATWG host policy lives upstack. Pass
  the same flag values to `normalization_profile_info()` for the matching
  profile identity.

## Deprecated

* `url_encode()`, `url_decode()`, and `parse_url()` are deprecated and now emit
  a `.Deprecated()` warning on use. They remain exported and fully functional
  for this release and are scheduled for removal in the next one. These were
  always best-effort host extraction/rewriting, not RFC 3986 / WHATWG URL
  parsing; use the `rurl` package for URL parsing and canonicalization, or pass
  the host alone to `host_normalize()` / `puny_encode()` / `puny_decode()` for
  host-only needs.

## Minor improvements

* `puny_encode()` / `puny_decode()` now reject URL-shaped input with a dedicated,
  actionable error (`looks_like_url`) pointing at `rurl::get_host()`, instead of
  the generic "ASCII domain labels may contain only letters, numbers and
  hyphens" message. Behavior is unchanged (URLs were always rejected; only the
  message is clearer).

## Internal

* `host_normalize()` is now verified against the official Unicode UTS #46
  conformance corpus (`IdnaTestV2.txt`, Unicode 16.0.0). The suite confirms
  full non-transitional ToASCII conformance, with one documented profile
  divergence: the trailing FQDN root dot is permitted (strict
  `VerifyDnsLength` would reject the empty root label).

# punycoder 1.1.0

## New Features

* `host_normalize()` converts hostnames to their canonical comparison form
  under a pinned UTS-46 profile (non-transitional, `UseSTD3ASCIIRules`,
  `CheckHyphens`, `CheckBidi`, `CheckJoiners`, NFC, DNS length verification),
  returning lowercase ASCII A-labels or `NA` for invalid input. The
  mapping/NFC/validation pipeline is implemented in-tree over vendored Unicode
  16.0.0 data, so behavior is independent of whether libidn2 is present.
* `normalization_profile_info()` exposes the machine-readable profile identity
  (`profile`, `unicode_version`, and the profile parameters) for downstream
  reproducibility keys.

# punycoder 1.0.0

First CRAN release.

## Bug Fixes

* `puny_decode()` (and the URL/domain decoders) now bound label length in both
  strict and non-strict mode. A crafted oversized `xn--` label previously drove
  the fallback decoder into quadratic time with unbounded allocation; oversized
  labels are now rejected promptly (error in strict mode, `NA` in non-strict).

## New Features

* Strict decoding now enforces RFC 5891 canonical A-label form: a decoded
  label must re-encode to itself. Non-canonical encodings (e.g. uppercase
  payloads) are rejected in strict mode while non-strict decoding stays lenient.
* Initial release of punycoder package
* Core punycode encoding and decoding functions (`puny_encode()`, `puny_decode()`)
* URL-aware processing functions (`url_encode()`, `url_decode()`, `parse_url()`)
* Domain validation and utility functions (`is_punycode()`, `is_idn()`, `validate_domain()`)
* Comprehensive test suite with RFC 3492 compliance testing
* High-performance C++ backend with Rcpp
* Vectorized operations for bulk processing
* Robust error handling and validation
* Complete documentation with vignettes

## Package Structure

* CRAN-compliant package structure
* MIT license
* Comprehensive test coverage
* Performance optimizations
* Cross-platform compatibility (Windows, macOS, Linux)

## Technical Implementation

* C++ backend using Rcpp for performance
* Placeholder implementation ready for libidn2 integration
* RFC 3492 compliance framework
* Extensive input validation
* Memory-efficient vectorized operations

## Documentation

* Complete function documentation with examples
* Introductory vignette
* README with quick start guide
* Test vectors from RFC 3492 specification

## Future Roadmap

* Integration with GNU libidn2 for production punycode implementation
* Performance optimizations
* Additional URL manipulation utilities
* Integration examples with popular R packages 