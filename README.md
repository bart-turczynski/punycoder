
<!-- README.md is generated from README.Rmd. Please edit that file -->

# punycoder

<!-- badges: start -->

[![R build
status](https://github.com/yourusername/punycoder/workflows/R-CMD-check/badge.svg)](https://github.com/yourusername/punycoder/actions)
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

## Installation

You can install the development version of punycoder from
[GitHub](https://github.com/) with:

``` r
# install.packages("remotes")
remotes::install_github("yourusername/punycoder")
```

## Example

``` r
library(punycoder)
#> punycoder: Unicode and Punycode Domain Name Processing
#> Type ?punycoder for help or see vignette('punycoder-intro')
#> Report issues at: https://github.com/yourusername/punycoder/issues

# Basic encoding (placeholder implementation)
puny_encode("example.com")
#> [1] "example.com"
#> attr(,"class")
#> [1] "punycoder_result" "character"       
#> attr(,"strict")
#> [1] TRUE
#> attr(,"input_encoding")
#> [1] "UTF-8"

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
- **CRAN Compliant**: Follows all CRAN policies and best practices

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

## Development Status

**Status**: This package is currently in development. The boilerplate
structure is complete and ready for implementation of the libidn2
backend.

The package now compiles cleanly and all R package infrastructure is
working correctly. Ready for implementing real punycode functionality!

## Contributing

We welcome contributions! Please see our [Contributing
Guide](CONTRIBUTING.md) for details.

## License

GPL-3
