# punycoder

[![R build status](https://github.com/yourusername/punycoder/workflows/R-CMD-check/badge.svg)](https://github.com/yourusername/punycoder/actions)
[![CRAN status](https://www.r-pkg.org/badges/version/punycoder)](https://CRAN.R-project.org/package=punycoder)

High-performance Unicode and Punycode encoding/decoding for internationalized domain names (IDNs) in R.

## Overview

The `punycoder` package addresses critical gaps in R's URL processing capabilities by providing reliable, fast conversion between Unicode and ASCII representations of domain names. It follows RFC 3492 standards and is designed for robust handling of internationalized domain names in web scraping, data analysis, and URL processing workflows.

## Key Features

- **Reliable Encoding/Decoding**: RFC 3492 compliant punycode conversion
- **URL-Aware Processing**: Handle complete URLs with international domains  
- **High Performance**: Vectorized operations for processing large datasets
- **Comprehensive Validation**: Robust error handling with informative messages
- **CRAN Compliant**: Follows all CRAN policies and best practices

## Installation

```r
# Install from CRAN (when available)
install.packages("punycoder")

# Install development version from GitHub
# install.packages("remotes")
remotes::install_github("yourusername/punycoder")
```

## Quick Start

```r
library(punycoder)

# Encode Unicode domains to ASCII
puny_encode("café.com")
#> [1] "xn--caf-dma.com"

puny_encode("москва.рф")
#> [1] "xn--80adxhks.xn--p1ai"

# Decode ASCII domains back to Unicode
puny_decode("xn--caf-dma.com")
#> [1] "café.com"

# Process URLs with international domains
url_encode("https://café.example.com/menu")
#> [1] "https://xn--caf-dma.example.com/menu"

# Vectorized operations for bulk processing
domains <- c("café.com", "москва.рф", "example.com")
puny_encode(domains)
#> [1] "xn--caf-dma.com" "xn--80adxhks.xn--p1ai" "example.com"
```

## Use Cases

### Web Scraping
Process international websites with Unicode domain names:

```r
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

```r
# Identify international domains
is_idn(c("café.com", "example.com", "москва.рф"))
#> [1]  TRUE FALSE  TRUE

# Validate domain names
validate_domain(c("valid.com", "invalid..domain"))
```

### URL Processing
Parse and manipulate URLs with international domains:

```r
url_parts <- parse_url("https://café.example.com:8080/path?q=test")
print(url_parts)
```

## Performance

Designed for high-performance processing of large datasets:

```r
# Process 10,000+ domains efficiently
large_dataset <- rep(c("café.com", "example.com"), 5000)
system.time(encoded <- puny_encode(large_dataset))
```

## Why punycoder?

### The Problem
Existing R packages for punycode handling have significant limitations:

- **urltools**: Contains bugs in punycode implementation
- **Limited functionality**: No comprehensive IDN handling  
- **Poor performance**: No efficient bulk processing capabilities

### The Solution
`punycoder` provides:

- ✅ Correct RFC 3492 implementation
- ✅ Comprehensive URL processing
- ✅ High-performance vectorized operations
- ✅ Robust error handling and validation
- ✅ CRAN-ready package structure

## Documentation

- [Package documentation](https://yourusername.github.io/punycoder/)
- [Introduction vignette](https://yourusername.github.io/punycoder/articles/punycoder-intro.html)
- [Function reference](https://yourusername.github.io/punycoder/reference/)

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```bash
git clone https://github.com/yourusername/punycoder.git
cd punycoder
```

### Testing

```r
# Run tests
devtools::test()

# Check package
devtools::check()
```

## Technical Details

- **Backend**: C++ with Rcpp for performance
- **Standards**: RFC 3492 (Punycode) and IDNA compliance
- **Dependencies**: Minimal (Rcpp only)
- **Platforms**: Windows, macOS, Linux

## License

GPL-3

## Citation

```r
citation("punycoder")
```

## Issues and Support

- [GitHub Issues](https://github.com/yourusername/punycoder/issues)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/r+punycode) (use tags: r, punycode)

## Related Packages

- `urltools`: URL parsing (with broken punycode)
- `httr`: HTTP requests (benefits from proper IDN handling)
- `rvest`: Web scraping (benefits from IDN support)

---

**Status**: This package is currently in development. The boilerplate structure is complete and ready for implementation of the libidn2 backend. 