
<!-- README.md is generated from README.Rmd. Please edit that file -->

# punycoder

<!-- badges: start -->

[![R build
status](https://github.com/bart-turczynski/punycoder/workflows/R-CMD-check/badge.svg)](https://github.com/bart-turczynski/punycoder/actions)
[![CRAN
status](https://www.r-pkg.org/badges/version/punycoder)](https://CRAN.R-project.org/package=punycoder)
<!-- badges: end -->

High-performance Unicode and Punycode encoding/decoding for
internationalized domain names (IDNs) in R.

## Overview

The `punycoder` package addresses critical gaps in R’s URL processing
capabilities by providing reliable, fast conversion between Unicode and
ASCII representations of domain names. It follows RFC 3492 standards and
is designed for robust handling of internationalized domain names in web
scraping, data analysis, and URL processing workflows.

## Dependencies

`punycoder` has a small dependency footprint:

- Runtime dependencies: `R (>= 3.5.0)`, `Rcpp`
- Optional system dependency: `libidn2` (detected at compile time)
- Optional build helper: `pkg-config` (used by `configure` to detect
  `libidn2`)
- Development dependencies: `testthat`, `knitr`, `rmarkdown`

## Installation

You can install the development version of punycoder from
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
- **URL-Aware Processing**: Handle complete URLs with international
  domains  
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

# Convert for HTTP requests
ascii_urls <- url_encode(international_urls)
```

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

- Domain encoding/decoding: `puny_encode()`, `puny_decode()`
- URL host processing: `url_encode()`, `url_decode()`, `parse_url()`
- Domain validation utilities: `is_punycode()`, `is_idn()`,
  `validate_domain()`
- Vectorized operations and strict/non-strict handling for malformed
  input
- Build-time backend selection (`libidn2` when present, built-in
  fallback otherwise)

## Acknowledgments

- Core C++/R integration is powered by `Rcpp`.
- Optional native punycode backend support is provided through
  `libidn2`.
- `punycoder` is inspired by `urltools` and is designed to provide a
  robust fix for punycode encode/decode issues that may arise in
  `urltools` workflows.

## Contributing

We welcome contributions! Please see our [Contributing
Guide](CONTRIBUTING.md) for details.

## License

MIT
