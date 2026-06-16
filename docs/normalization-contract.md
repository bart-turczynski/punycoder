# Canonical-host normalization contract

> Status: **ratified 2026-06-14** (normative). Drives the punycoder
> normalization API that `pslr` depends on (tracker: PSLR-bibhwmuf, parent
> PSLR-ncplpipo). `pslr` must not infer any of this; punycoder owns and
> documents it.
>
> Audience: punycoder maintainer and the implementation/parity-test agents for
> PSLR-encodgsk and PSLR-gnmvyymh.

## 0. Ratified decisions

The maintainer ratified these three load-bearing choices on 2026-06-14. They
are normative; changing any of them follows section 8 versioning.

1. **Profile = UTS-46, non-transitional, STD3-restricted.** Unicode Technical
   Standard #46 (IDNA Compatibility Processing) is the normalization package
   rather than bare IDNA2008 or IDNA2003. Non-transitional processing matches
   current browser behavior. `UseSTD3ASCIIRules = true` restricts ASCII labels
   to letters/digits/hyphen (rejects `_`, etc.). See section 3.
2. **punycoder owns the mapping/NFC/validation pipeline; libidn2 is optional
   only for the deterministic Punycode (RFC 3492) transform.** This is the only
   architecture that makes behavior provably backend-independent, because the
   in-tree fallback today performs *no* normalization. See section 6.
3. **One pinned Unicode version per release: Unicode 16.0.0.** The vendored
   UTS-46 + NFC data fixes `unicode_version = "16.0.0"`. Changing it is a
   behavior change requiring a punycoder release and a `pslr` compatibility
   review. See sections 4 and 7.

## 1. Purpose and scope

punycoder exposes one documented function that converts a DNS hostname to its
canonical comparison form: Unicode NFC normalization, case normalization,
UTS-46 label mapping and validation, and conversion to lowercase ASCII
A-labels, while preserving whether the input carried exactly one terminal root
dot.

In scope:

- whole-host normalization of a character vector of hostnames;
- U-label, A-label (`xn--`), mixed-case, single-label, and single-terminal-dot
  inputs;
- a stable, machine-readable profile identity (`normalization_profile`,
  `unicode_version`) for reproducibility.

Out of scope (the caller's concern, e.g. `pslr`):

- URL parsing, authority extraction, port/path handling;
- IP-address-literal detection and rejection — under STD3 rules `1.2.3.4`
  normalizes to `1.2.3.4`; rejecting IP literals is the caller's job;
- the policy for what to *do* with an invalid element (return `NA` vs. abort) —
  this function reports invalidity; the caller chooses the policy;
- **spoof / homograph / mixed-script / display-safety detection** — see the
  Non-goals section below.

### Non-goals: spoofing and display safety (normative)

`host_normalize()` is **not a safety gate.** Confusable, homograph,
mixed-script, and display-safety detection — the concerns of **UTS #39**
(Unicode Security Mechanisms) and **UTR #36** (Unicode Security
Considerations) — are explicitly **not part of this function's acceptance
criteria.** A successful (non-`NA`) result asserts only that the host is valid
and normalized under the pinned UTS #46 profile; it asserts **nothing** about
whether the host is visually safe, non-deceptive, or distinguishable from
another host.

This is a deliberate scope boundary, not an oversight. UTS #46 §6 itself
*recommends* applying UTR #36 / UTS #39 confusable and restriction-level checks
as additional **application/UI-layer** steps on top of normalization — which is
precisely the argument for placing them upstack (in `rurl` or a dedicated
policy layer), not inside the normalization primitive. "Not part of the
acceptance criteria" means not in punycoder, not "never relevant".

## 2. Signature

```r
host_normalize(x, check_hyphens = TRUE, use_std3 = TRUE, verify_dns_length = TRUE)
```

- `x`: character vector of hostnames. `NA_character_` is passed through as
  `NA_character_` (missing, not invalid).
- `check_hyphens`, `use_std3`, `verify_dns_length`: logical scalars, the three
  UTS #46 processing flags exposed as knobs. Each defaults to `TRUE` (the full
  `uts46-nontransitional-std3-v1` profile); each may be relaxed independently.
  Behavior must **not** read the process-wide `punycoder.strict` option
  (PRD §4). `CheckBidi` and `CheckJoiners` always apply and are **not** knobs.
  These are UTS #46 parameters, not a browser mode: full WHATWG host policy
  (where `beStrict = false` flips exactly these three) lives upstack in `rurl`.
- Returns: character vector, `length(x)`, names preserved. Each element is the
  canonical lowercase ASCII A-label host, or `NA_character_` when the input is
  invalid under the profile. The function never aborts on invalid *data*; it
  aborts only on programming errors (wrong type, non-scalar flag).

Returning `NA` for invalid input — rather than throwing under `strict = TRUE`,
as the existing `puny_encode()` does — is intentional and lets the caller layer
its own `invalid = c("na", "error")` policy. This new function does not inherit
`puny_encode()`'s throw-on-strict convention.

Profile identity is read separately (section 7), not returned per element.

## 3. Normalization profile (normative)

The profile is **UTS-46** with these parameters, fixed for v1:

| Parameter | Value |
|---|---|
| `Transitional_Processing` | `false` (non-transitional) |
| `UseSTD3ASCIIRules` | `true` |
| `CheckHyphens` | `true` |
| `CheckBidi` | `true` |
| `CheckJoiners` | `true` |
| `VerifyDnsLength` | `true` (label 1–63 octets; total ≤ 253, excluding the root dot) |

`normalization_profile = "uts46-nontransitional-std3-v1"`. The `-v1` suffix is a
profile revision: any change to the parameters above, or to the accept/reject or
output of the algorithm in section 4, increments it.

## 4. Algorithm (normative, per element)

For each non-`NA` element of `x`:

1. **Reject non-UTF-8 / ill-formed input** → `NA`.
2. **Terminal-dot capture.** If the string ends with exactly one `.`, record
   "had root dot" and strip that single dot. A string that is only `"."`, ends
   with two or more dots, or is empty after this step is invalid → `NA`.
3. **UTS-46 processing** at the pinned Unicode version, with the section 3
   parameters:
   a. **Map** each code point (case fold, map, or mark disallowed) via the
      pinned `IdnaMappingTable`. A disallowed code point → `NA`.
   b. **Normalize** the mapped string to **NFC**.
   c. **Break** into labels on `U+002E FULL STOP`.
   d. For each label: if it begins with `xn--`, decode the A-label to a U-label
      and verify it is valid and re-encodes to the identical A-label (RFC 5891
      §5.4 canonical form); a non-canonical A-label → `NA`. Validate every label
      against the profile (NFC form, `CheckHyphens`, `CheckBidi`,
      `CheckJoiners`, no empty labels, STD3 for ASCII).
4. **Encode** every non-ASCII label back to its `xn--` A-label via Punycode
   (RFC 3492). ASCII labels are emitted lowercased.
5. **Length verification** (`VerifyDnsLength`): each A-label 1–63 octets; total
   joined length ≤ 253 octets. Violation → `NA`.
6. **Reassemble** labels with `.`; if "had root dot" was recorded, append one
   `.`. The result is all-lowercase ASCII.

Empty labels (from leading dots or consecutive dots) are invalid at step 3c →
`NA`. This makes leading-dot, consecutive-dot, and multi-terminal-dot inputs
invalid, matching the caller's input contract.

## 5. Worked examples (contract test seeds)

| Input | Output | Note |
|---|---|---|
| `"Example.COM"` | `"example.com"` | case fold |
| `"example.com."` | `"example.com."` | single root dot preserved |
| `"münchen.de"` | `"xn--mnchen-3ya.de"` | U-label → A-label |
| `"xn--mnchen-3ya.de"` | `"xn--mnchen-3ya.de"` | canonical A-label kept |
| `"XN--MNCHEN-3YA.de"` | `"xn--mnchen-3ya.de"` | A-label ACE prefix case-folded; payload canonical |
| `"xn--MNCHEN-3ya.de"` | `"xn--mnchen-3ya.de"` | A-label payload case-folded (Punycode basic code points are case-insensitive) |
| `"faß.de"` | `"xn--fa-hia.de"` | non-transitional maps `ß`→`ss`? **No** — non-transitional keeps `ß`; see below |
| `"a_b.com"` | `NA` | STD3 rejects `_` |
| `".com"` | `NA` | leading dot → empty label |
| `"a..b"` | `NA` | consecutive dots → empty label |
| `"1.2.3.4"` | `"1.2.3.4"` | not rejected here; IP-literal policy is the caller's |
| `""` | `NA` | empty |
| `NA` | `NA` | missing, passed through |

Correction on `faß.de`: under **non-transitional** UTS-46, `ß` (U+00DF) is
*valid* and preserved, giving `xn--fa-hia.de`; only **transitional** processing
maps it to `ss`. Because this contract pins non-transitional, the canonical
output is `"xn--fa-hia.de"`. This row is the canonical regression fixture for
the transitional/non-transitional decision and must be asserted directly.

## 6. Backend parity model (normative)

The fallback backend currently performs no normalization (only RFC 3492). To
guarantee behavior is independent of whether libidn2 is present:

- The **mapping, NFC, label validation, and A-label canonical check** (section
  4 steps 1–3, 5, 6) are **always** performed by punycoder's own code using the
  pinned in-tree Unicode data. libidn2 is **not** consulted for these.
- libidn2, when available, may be used **only** for the deterministic Punycode
  encode/decode of an individual label (section 4 step 4 and the decode in 3d).
  RFC 3492 is fully determined by the input code points, so this substitution
  cannot change accept/reject or output.

Consequently `normalization_profile` and `unicode_version` are properties of the
vendored data, not of the backend, and are identical with or without libidn2.
Parity is verified over fixtures (PSLR-gnmvyymh): the PSL rule corpus, official
IDN/UTS-46 fixtures, and the package edge-case fixtures (section 5) must yield
byte-identical output and identical accept/reject under both backends.

This narrows libidn2's role from "IDNA engine" to "Punycode accelerator." That
is a deliberate trade: it is the only way to honor the PRD requirement that
optional libidn2 "must not change behavior."

## 7. Profile identity API (normative)

```r
normalization_profile_info()
```

Returns a one-row base `data.frame` (stable column names and types):

| Column | Type | Meaning |
|---|---|---|
| `profile` | character | `"uts46-nontransitional-std3-v1"` |
| `unicode_version` | character | pinned data version: `"16.0.0"` |
| `idna` | character | `"uts46"` |
| `transitional` | logical | `FALSE` |
| `use_std3` | logical | `TRUE` |
| `check_hyphens` | logical | `TRUE` |
| `check_bidi` | logical | `TRUE` |
| `check_joiners` | logical | `TRUE` |
| `backend` | character | diagnostic only: `"fallback"`, `"libidn2"`, or `"libidn2+fallback"` — **not** part of profile identity |

`pslr::psl_version()` reads `profile` → `normalization_profile` and
`unicode_version` from this, plus the installed punycoder package version as
`normalizer_version`. `backend` is diagnostic and must never enter a
reproducibility key or a cache key.

The pinned `unicode_version` is `"16.0.0"`, fixed at build time from the
vendored UTS-46 + normalization data. There is exactly one such version per
punycoder release.

## 8. Versioning

- Changing any section 3 parameter, the section 4 algorithm, or the pinned
  Unicode data is a behavior change: increment the `-vN` profile revision, bump
  the punycoder version, record old/new `unicode_version` in `NEWS.md`, and
  trigger a `pslr` compatibility review before `pslr` raises its accepted
  punycoder version.
- The relaxed flags (`check_hyphens`, `use_std3`, `verify_dns_length`) are
  monotone: relaxing any of them must never change a result the full profile
  already accepts, only ever turn rejections into acceptances. Verified across
  the IdnaTestV2 corpus.

## 9. Acceptance criteria for this contract (PSLR-bibhwmuf)

- [x] Maintainer ratifies the three section-0 decisions. (2026-06-14)
- [x] `host_normalize()` signature and `NA`-on-invalid semantics agreed.
- [x] Profile parameters (section 3) and the `normalization_profile` token
      agreed (`uts46-nontransitional-std3-v1`).
- [x] `unicode_version` baseline pinned: `16.0.0`.
- [x] Section 5 examples adopted as the seed contract-test fixtures.
- [x] `normalization_profile_info()` schema agreed, with `pslr::psl_version()`
      consuming `profile` + `unicode_version`.

Contract ratified. Implementation (PSLR-encodgsk), parity tests
(PSLR-gnmvyymh), and release (PSLR-obdfxkqb) may proceed.

## 10. Standards and references

`host_normalize()` implements a **pinned UTS #46 non-transitional ToASCII
profile**. UTS #46 is *compatibility processing* and is **deliberately not
identical to IDNA2008**: it accepts labels IDNA2008 would reject (e.g.
`☕.example` → `xn--53h.example`), and WHATWG specifies UTS #46 "and not
IDNA2008". This function must therefore be described as a UTS #46 profile,
**never** as IDNA2008 / RFC 5891 conformance.

Standards this profile draws on, mapped to where each is used:

- **UTS #46** (*Unicode IDNA Compatibility Processing*) — the overall mapping +
  validation profile (section 3; algorithm steps 3a/3c/3d). UTS #46 §6 also
  *recommends* UTR #36 / UTS #39 confusable checks as application/UI-layer
  steps — out of scope here (section 1, Non-goals).
- **RFC 3492** (*Punycode*, the IDNA parameterization of Bootstring) — the
  deterministic A-label ↔ U-label transform (step 4, and the re-encode check in
  step 3d). The only step the optional libidn2 backend may serve (section 6).
- **RFC 5890** (*IDNA2008 Definitions/Framework*) — the `xn--` ACE prefix and
  the A-label / U-label / LDH vocabulary. `puny_encode()` emitting `xn--` is RFC
  5890 framing, not RFC 3492.
- **RFC 5891** (*IDNA2008 Protocol*) — the §5.4 canonical-A-label requirement
  enforced in step 3d. Cited for that specific check only; see the UTS #46 ≠
  IDNA2008 note above — we do **not** claim RFC 5891 conformance.
- **RFC 5892** (*The Unicode Code Points and IDNA*) — derived property values
  and contextual rules. Our `CheckJoiners` uses the RFC 5892 **ContextJ** rules
  for ZWJ/ZWNJ (`punycoder_normalize.cpp:69-86`, `Joining_Type` tables). We do
  **NOT** implement full RFC 5892 **CONTEXTO** validation: CONTEXTO code points
  that the UTS #46 mapping table marks `valid` (e.g. U+00B7 middle dot, Greek
  keraia U+0375, Hebrew geresh/gershayim, Katakana middle dot U+30FB) are
  accepted with no CONTEXTO check. That is conformant UTS #46 (which mandates
  CheckJoiners, not CONTEXTO); adding CONTEXTO would be a separate, deliberate
  change.
- **RFC 5893** (*Right-to-Left Scripts for IDNA*) — the Bidi rule enforced by
  `CheckBidi`.
- **UAX #15** (*Unicode Normalization Forms*) — NFC (step 3b).
- **UAX #44** (*Unicode Character Database*) — the property tables consumed:
  `Bidi_Class`, `Joining_Type`, `General_Category`, `Canonical_Combining_Class`.
- **STD 3** (= **RFC 952** + **RFC 1123**) — the host-name letter/digit/hyphen
  rules behind `UseSTD3ASCIIRules`.
- **RFC 8753** (*IDNA Review for New Unicode Versions*) — rationale for pinning
  one Unicode version per release (sections 7, 8).

Consciously **not** used (rejected alternative): **RFC 3490 / 3491 / 3454**
(IDNA2003 / Nameprep / Stringprep). The UTS #46 non-transitional profile
supersedes them. **RFC 5894** (IDNA2008 rationale, informational) is background
reading, not a normative dependency.

The best-effort URL helpers (`url_*` / `parse_url()`, `punycoder_url.cpp`) are
**not** conformant to **RFC 3986** (URI), **RFC 3987** (IRI), the **WHATWG URL
Standard**, **RFC 5952** (IPv6 text form), **RFC 4291** (IPv6 addressing), or
**RFC 6874** (IPv6 zone IDs); those citations belong with that surface and move
with it if it migrates to a dedicated URL package.
