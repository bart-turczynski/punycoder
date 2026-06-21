
<!-- README.md is generated from README.Rmd. Please edit that file -->

# punycoder

<!-- badges: start -->

[![Verify](https://github.com/bart-turczynski/punycoder/actions/workflows/verify.yml/badge.svg)](https://github.com/bart-turczynski/punycoder/actions/workflows/verify.yml)
[![CRAN
status](https://www.r-pkg.org/badges/version/punycoder)](https://CRAN.R-project.org/package=punycoder)
[![CRAN
downloads](https://cranlogs.r-pkg.org/badges/punycoder)](https://CRAN.R-project.org/package=punycoder)
[![Codecov
coverage](https://codecov.io/gh/bart-turczynski/punycoder/branch/main/graph/badge.svg)](https://app.codecov.io/gh/bart-turczynski/punycoder)
[![Lifecycle:
stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
<!-- badges: end -->

High-performance Unicode and Punycode encoding/decoding for
internationalized domain names (IDNs) in R.

## Overview

The `punycoder` package provides fast, standards-based conversion
between Unicode and ASCII representations of domain names, across two
distinct surfaces:

- a **low-level Punycode codec** — `puny_encode()` / `puny_decode()` —
  the raw RFC 3492 transform with `xn--` A-label framing (RFC 5890/5891)
  and letter-digit-hyphen checks, **not** an IDNA normalization API (no
  Unicode NFC, UTS \#46 mapping, or case folding);
- an **IDNA/UTS-46 host-normalization surface** — `host_normalize()` —
  mapping a host name to its canonical lowercase ASCII comparison form
  under a pinned UTS \#46 non-transitional profile.

`host_normalize()` is a **UTS \#46 profile, not IDNA2008 conformance** —
UTS \#46 is compatibility processing and deliberately accepts labels
IDNA2008 would reject (e.g. `☕.example` → `xn--53h.example`). See
[`docs/normalization-contract.md`](docs/normalization-contract.md) for
the normative profile and full standards references (RFC
3492/5890/5891/5892/5893, UTS \#46, UAX \#15/#44, STD 3, RFC 8753).

## Dependencies

`punycoder` has a small dependency footprint:

- Runtime dependencies: `R (>= 3.5.0)`, `Rcpp`
- Optional system dependency: `libidn2` (detected at compile time)
- Optional build helper: `pkg-config` (used by `configure` to detect
  `libidn2`)
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

`punycoder` works without extra system libraries. If `libidn2` is
available at build time, the package enables a native backend
automatically; otherwise it uses the built-in C++ fallback backend.

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
- **Best-effort host rewriting**: Swap the host of a URL-shaped string
  in place (not a full URL parser; see below)
- **High Performance**: Vectorized operations for processing large
  datasets
- **Comprehensive Validation**: Robust error handling with informative
  messages
- **Flexible Backend**: Automatically uses `libidn2` when available,
  with a built-in fallback backend

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

> `url_encode()`, `url_decode()`, and `parse_url()` do **best-effort
> host extraction and rewriting**, not RFC 3986 / WHATWG URL parsing or
> canonicalization. They have no percent encoding/decoding, scheme
> validation, robust port/path/query semantics, full IPv6 (zone IDs /
> RFC 6874), or serialization guarantees, and are slated for eventual
> removal in favour of a dedicated URL package consuming punycoder’s
> host functions. Use `host_normalize()` / `puny_encode()` directly when
> you control the host parse.

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
- IDNA/UTS-46 host normalization: `host_normalize()`,
  `normalization_profile_info()`
- Best-effort URL host rewriting/extraction (not URL
  parsing/canonicalization): `url_encode()`, `url_decode()`,
  `parse_url()`
- Domain validation utilities: `is_punycode()`, `is_idn()`,
  `validate_domain()`
- Vectorized operations and strict/non-strict handling for malformed
  input
- Build-time backend selection (`libidn2` when present, built-in
  fallback otherwise)
- Best-effort structured host extraction where invalid inputs are
  returned as missing components

## Non-goals

`punycoder` is a standards primitive for Punycode and host
normalization. It is deliberately agnostic about resolvability and
safety; the following are **not** part of its acceptance criteria:

- **No spoof / homograph / mixed-script / display-safety detection.**
  `host_normalize()` is not a safety gate — a successful result says the
  host is valid and normalized under the pinned UTS \#46 profile,
  nothing about whether it is visually safe or non-deceptive. Confusable
  and restriction-level checks (UTS \#39 / UTR \#36, which UTS \#46
  itself recommends only as application/UI-layer steps) belong upstack.
- **No URL canonicalization.** The `url_*` / `parse_url()` helpers do
  best-effort host rewriting only (see above), not RFC 3986 / WHATWG URL
  parsing.
- **No DNS resolvability or registrability / PSL classification.**

These opinions belong in higher layers that consume punycoder’s host
functions.

## Acknowledgments

- Core C++/R integration is powered by `Rcpp`.
- Optional native punycode backend support is provided through
  `libidn2`.
- `punycoder` is inspired by `urltools` and is designed to provide a
  robust fix for punycode encode/decode issues that may arise in
  `urltools` workflows.

## Related packages

`punycoder` is part of a small ecosystem of R packages by the same author:

- **[pslr](https://bart-turczynski.github.io/pslr/)** — Public Suffix List engine that uses `punycoder` for IDNA canonicalization. Use it for eTLD and registrable-domain queries.
- **[rurl](https://bart-turczynski.github.io/rurl/)** — Full URL parsing, normalization, and joining toolkit built on top of both `punycoder` and `pslr`.

## Contributing

We welcome contributions. See
[CONTRIBUTING.md](https://github.com/bart-turczynski/punycoder/blob/main/CONTRIBUTING.md)
for the current development workflow.

## License

MIT
