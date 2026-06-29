
<!-- README.md is generated from README.Rmd. Please edit that file -->

# punycoder

<!-- badges: start -->

[![Verify](https://github.com/bart-turczynski/punycoder/actions/workflows/verify.yml/badge.svg)](https://github.com/bart-turczynski/punycoder/actions/workflows/verify.yml)
[![CRAN status](https://www.r-pkg.org/badges/version/punycoder)](https://CRAN.R-project.org/package=punycoder)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/punycoder)](https://CRAN.R-project.org/package=punycoder)
[![Codecov coverage](https://codecov.io/gh/bart-turczynski/punycoder/branch/main/graph/badge.svg)](https://app.codecov.io/gh/bart-turczynski/punycoder)
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20973629.svg)](https://doi.org/10.5281/zenodo.20973629)
[![Zenodo](https://img.shields.io/badge/Zenodo-all_software-1682D4?logo=zenodo&logoColor=white)](https://zenodo.org/search?q=metadata.creators.person_or_org.identifiers.identifier:0000-0002-8788-7980)
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fbart-turczynski%2Fpunycoder.svg?type=shield&issueType=license)](https://app.fossa.com/projects/git%2Bgithub.com%2Fbart-turczynski%2Fpunycoder?ref=badge_shield&issueType=license)
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fbart-turczynski%2Fpunycoder.svg?type=shield&issueType=security)](https://app.fossa.com/projects/git%2Bgithub.com%2Fbart-turczynski%2Fpunycoder?ref=badge_shield&issueType=security)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/13429/badge)](https://www.bestpractices.dev/projects/13429)
<!-- badges: end -->

High-performance Unicode and Punycode encoding/decoding for internationalized domain names (IDNs) in R.

## Overview

The `punycoder` package provides fast, standards-based conversion between Unicode and ASCII representations of domain names, across two distinct surfaces:

- a **low-level Punycode codec** — `puny_encode()` / `puny_decode()` — the raw RFC 3492 transform with `xn--` A-label framing (RFC 5890/5891) and letter-digit-hyphen checks, **not** an IDNA normalization API (no Unicode NFC, UTS \#46 mapping, or case folding);
- an **IDNA/UTS-46 host-normalization surface** — `host_normalize()` — mapping a host name to its canonical lowercase ASCII comparison form under a pinned UTS \#46 non-transitional profile.

`host_normalize()` is a **UTS \#46 profile, not IDNA2008 conformance** — UTS \#46 is compatibility processing and deliberately accepts labels IDNA2008 would reject (e.g. `☕.example` → `xn--53h.example`). See `?host_normalize` and `normalization_profile_info()` for the normative profile and full standards references (RFC 3492/5890/5891/5892/5893, UTS \#46, UAX \#15/#44, STD 3, RFC 8753).

## Dependencies

`punycoder` has a small dependency footprint:

- Runtime dependencies: `R (>= 3.5.0)`, `Rcpp`
- Optional system dependency: `libidn2` (detected at compile time)
- Optional build helper: `pkg-config` (used by `configure` to detect `libidn2`)
- Development dependencies: `testthat`, `knitr`, `rmarkdown`

## Installation

Install the released version of punycoder from
[CRAN](https://CRAN.R-project.org/package=punycoder) with:

``` r
install.packages("punycoder")
```

Or install the development version from
[GitHub](https://github.com/bart-turczynski/punycoder) with:

``` r
# install.packages("remotes")
remotes::install_github("bart-turczynski/punycoder")
```

### Optional native backend (`libidn2`)

`punycoder` works without extra system libraries. If `libidn2` is available at
build time, the package enables a native backend automatically; otherwise it
uses the built-in C++ fallback backend.

To install the recommended optional dependency:

- macOS (Homebrew):
  - `brew install libidn2 pkg-config`
- Debian/Ubuntu:
  - `sudo apt-get install libidn2-0-dev pkg-config`
- Fedora/RHEL/CentOS:
  - `sudo dnf install libidn2-devel pkgconf-pkg-config`
- Arch Linux:
  - `sudo pacman -S libidn2 pkgconf`

Verify the library is visible before installing `punycoder` from source:

``` r
system("pkg-config --modversion libidn2")
```

Then install/reinstall `punycoder`:

``` r
remotes::install_github("bart-turczynski/punycoder")
```

## Example

``` r
library(punycoder)

# Basic encoding
puny_encode("café.com")
#> [1] "xn--caf-dma.com"

# Check if domain is punycode
is_punycode("xn--example")
#> [1] TRUE

# Validate domains
validate_domain("test.com")
#> Punycoder Domain Validation Results
#> ==================================
#> 
#> Domain: test.com 
#> Valid:  TRUE
```

## Key Features

- **Reliable Encoding/Decoding**: RFC 3492 compliant punycode conversion
- **Best-effort host rewriting**: Swap the host of a URL-shaped string in place (not a full URL parser; see below)
- **High Performance**: Vectorized operations for processing large datasets
- **Comprehensive Validation**: Robust error handling with informative messages
- **Flexible Backend**: Automatically uses `libidn2` when available, with a built-in fallback backend

## Use Cases

### Web Scraping

Process international websites with Unicode domain names:

``` r
international_urls <- c(
  "https://café.paris.fr/menu",
  "https://москва.рф/news",
  "https://北京.中国/info"
)

# Convert for HTTP requests (best-effort host rewriting only)
ascii_urls <- url_encode(international_urls)
```

> `url_encode()`, `url_decode()`, and `parse_url()` do **best-effort host
> extraction and rewriting**, not RFC 3986 / WHATWG URL parsing or
> canonicalization. They have no percent encoding/decoding, scheme validation,
> robust port/path/query semantics, full IPv6 (zone IDs / RFC 6874), or
> serialization guarantees, and are slated for eventual removal in favor of a
> dedicated URL package consuming punycoder’s host functions. Use
> `host_normalize()` / `puny_encode()` directly when you control the host
> parse.

### Data Analysis

Clean and standardize URL datasets:

``` r
# Identify international domains
is_idn(c("café.com", "example.com", "москва.рф"))

# Validate domain names
validate_domain(c("valid.com", "invalid..domain"))
```

## Current State

`punycoder` currently provides:

- Low-level Punycode codec: `puny_encode()`, `puny_decode()`
- IDNA/UTS-46 host normalization: `host_normalize()`, `normalization_profile_info()`
- Best-effort URL host rewriting/extraction (not URL parsing/canonicalization): `url_encode()`, `url_decode()`, `parse_url()`
- Domain validation utilities: `is_punycode()`, `is_idn()`, `validate_domain()`
- Vectorized operations and strict/non-strict handling for malformed input
- Build-time backend selection (`libidn2` when present, built-in fallback otherwise)
- Best-effort structured host extraction where invalid inputs are returned as missing components

## Non-goals

`punycoder` is a standards primitive for Punycode and host normalization. It is
deliberately agnostic about resolvability and safety; the following are **not**
part of its acceptance criteria:

- **No spoof / homograph / mixed-script / display-safety detection.**
  `host_normalize()` is not a safety gate — a successful result says the host is
  valid and normalized under the pinned UTS \#46 profile, nothing about whether it
  is visually safe or non-deceptive. Confusable and restriction-level checks
  (UTS \#39 / UTR \#36, which UTS \#46 itself recommends only as application/UI-layer
  steps) belong upstack.
- **No URL canonicalization.** The `url_*` / `parse_url()` helpers do best-effort
  host rewriting only (see above), not RFC 3986 / WHATWG URL parsing.
- **No DNS resolvability or registrability / PSL classification.**
- **No address parsing.** There is no `email`-to-ASCII helper; splitting an
  address and IDNA-encoding its domain part is an addressing concern for an
  upstack consumer, not a Punycode primitive.
- **No per-TLD repertoire / allowed-character validation.** `host_normalize()`
  validates against the pinned UTS \#46 profile, not against registry-specific
  IDN tables (which evolve independently of Unicode). TLD policy belongs upstack.

These opinions belong in higher layers that consume punycoder’s host functions.

## Prior art and comparison

Punycode/IDN libraries exist in most ecosystems. `punycoder` is most directly a
maintained, IDNA2008-era successor to the libidn-based R tooling — its public
API (`puny_encode()` / `puny_decode()` / `is_punycode()`) descends from
[`hrbrmstr/punycode`](https://github.com/hrbrmstr/punycode). The table below
situates it against representative libraries.

|  | **punycoder** (R) | [hrbrmstr/punycode](https://github.com/hrbrmstr/punycode) (R) | [punycoder](https://pub.dev/packages/punycoder) (Dart) | [simonmittag/punycoder](https://github.com/simonmittag/punycoder) (Go) |
|----|----|----|----|----|
| Form | library | library | library | CLI tool |
| RFC 3492 codec | yes | yes | yes | yes |
| Engine | `libidn2` + in-tree fallback | GNU `libidn` | pure Dart | Go `x/net/idna` |
| IDNA standard | 2008 / UTS #46 (non-transitional) | 2003 (nameprep) | RFC 3492 + IDNA helpers | UTS #46 (via `x/net`) |
| Unicode NFC | explicit (UAX #15) | implicit in nameprep | not documented | via `x/net` |
| Pinned Unicode version | yes — 16.0.0, regenerable | no (frozen at build) | no | tracks Go release |
| CheckBidi / CheckJoiners | always on | not surfaced | not documented | partial |
| UTS #46 conformance corpus (`IdnaTestV2`) | yes | no | no | — |
| Strict / `NA` per-element policy | yes | undocumented | `validate` flag | n/a (CLI) |
| Vectorized | yes | yes | n/a | n/a |
| Maintenance | active | last commit 2015 | maintained | maintained |

> The most consequential row is **IDNA standard**. IDNA2003 (GNU `libidn`,
> nameprep) and IDNA2008 / UTS #46 disagree on real domains: the *deviation
> characters* `ß`, `ς`, and the joiners ZWJ/ZWNJ. Under IDNA2003 `faß.de` is
> mapped to `fass.de` — a **different host** — whereas `punycoder`’s pinned
> UTS #46 non-transitional profile preserves it as `xn--fa-hia.de`. A
> libidn-era pipeline therefore silently rewrites some hosts rather than
> erroring, which is the class of bug `punycoder` exists to remove.

> Comparisons reflect each project’s public documentation as of this writing and
> describe documented behavior, not an independent audit.

### Observed behavior on the comparable R packages

Running the same inputs through the comparable R packages surfaces concrete
behavioral differences (observed against `punycode` 0.2.5, `urltools` 1.7.3.1,
and the author’s own upstack toolkit [`rurl`](https://bart-turczynski.github.io/rurl/)
1.4.0). The raw RFC 3492 codec output agrees byte-for-byte across the codecs
once direction is aligned — the divergences are in multi-label handling,
idempotency, validity philosophy, and input scope. `rurl` is a URL
parser/normalizer rather than a Punycode codec; it is included to show where the
URL-shaped inputs `punycoder` deliberately rejects are actually handled (it
delegates IDNA host conversion to `punycoder`), so `—` below means “out of
scope for that layer,” not a defect:

| Behavior | **punycoder** | hrbrmstr/punycode | urltools | rurl |
|----|----|----|----|----|
| Primary role | Punycode/IDNA host codec | Punycode codec (IDNA2003) | URL + punycode utilities | URL parser / normalizer |
| `puny_encode()` direction | Unicode → ASCII | **ASCII → Unicode** (names inverted) | Unicode → ASCII | — (no codec; IDNA via `punycoder`) |
| Decode multi-label `xn--hxakfddc2amo8b.xn--qxam` | `ελράδειγμα.ελ` ✓ | `ελράδειγμα.ελ` ✓ | `ελράδειγμα.ελράδειγμα` ✗ (second label corrupted) | — (no `xn--` → Unicode decoder) |
| Re-encode an already-`xn--` label | unchanged — idempotent ✓ | unchanged ✓ | `xn--xn--…-.xn--xn--…-` ✗ (double-encoded) | — |
| Round-trip `decode(encode(x)) == x` | yes | yes | no (from the decode bug above) | — |
| `gr€€n.no` — EURO SIGN, valid under UTS #46 | accepted → `xn--grn-l50aa.no` | rejected by `puny_tld_check` (IDNA2008) | — | parses; host preserved |
| Full-URL input (`http://…`) | rejected with an actionable error pointing at a URL parser (`rurl`) | n/a (domain-only) | passed through unchanged | **parsed** — scheme/host/domain/TLD extracted; `get_clean_url()` lowercases the host and resolves dot-segments |
| Required system library | none (`libidn2` optional) | GNU `libidn` (v1) required to build | none | none |

> `punycode` names its functions opposite to the usual convention:
> `punycode::puny_encode()` maps `xn--` → Unicode and
> `punycode::puny_decode()` maps Unicode → `xn--`. The rows above align
> by transform direction, not by function name.
>
> `punycoder` + `rurl` (+ [`pslr`](https://bart-turczynski.github.io/pslr/) for
> the public-suffix/TLD truth) are designed to compose: `rurl` parses the URL and
> hands the host to `punycoder` for IDNA canonicalization, each package owning a
> single concern.

## Acknowledgments

These packages build on data, libraries, and prior work from many others.
See [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md) for the full list of thanks.

## Related packages

`punycoder` is part of a small ecosystem of R packages by the same author:

- **[pslr](https://bart-turczynski.github.io/pslr/)** — Public Suffix List engine that uses `punycoder` for IDNA canonicalization. Use it for eTLD and registrable-domain queries.
- **[rurl](https://bart-turczynski.github.io/rurl/)** — Full URL parsing, normalization, and joining toolkit built on top of both `punycoder` and `pslr`.

## Citation

If you use `punycoder` in your work, please cite it. Run `citation("punycoder")`
for the current citation, or see [`CITATION.cff`](CITATION.cff).

Each release is archived on Zenodo. Cite the concept DOI
[10.5281/zenodo.20973629](https://doi.org/10.5281/zenodo.20973629) to refer to
the software in general (it always resolves to the latest version), or the
version-specific DOI shown on the [Zenodo
record](https://doi.org/10.5281/zenodo.20973629) for a particular release.

## Contributing

We welcome contributions. See [CONTRIBUTING.md](https://github.com/bart-turczynski/punycoder/blob/main/CONTRIBUTING.md) for the
current development workflow.

## Code of Conduct

Please note that this package is released with a [Contributor Code of Conduct](https://ropensci.org/code-of-conduct/). By contributing to this project, you agree to abide by its terms.

## License

MIT
