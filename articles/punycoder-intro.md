# Introduction to punycoder

## Introduction

The `punycoder` package provides high-performance Unicode and Punycode
encoding/decoding for internationalized domain names (IDNs). It
addresses critical gaps in R’s URL processing capabilities by offering
reliable, fast conversion between Unicode and ASCII representations of
domain names.

### Why punycoder?

#### The Problem

International domain names containing Unicode characters (like café.com
or москва.рф) need to be converted to ASCII format for use in many
network protocols and systems. Existing R packages have limitations:

- **Inconsistent legacy helpers**: Existing workflows may produce
  incorrect punycode output
- **Limited functionality**: No comprehensive IDN handling
- **Performance**: No efficient bulk processing

#### The Solution

`punycoder` provides:

- **Reliable encoding/decoding** following RFC 3492 standards
- **URL-aware processing** for complete URL handling
- **High performance** for large datasets
- **Comprehensive validation** with informative error messages

### Basic Usage

#### Domain Encoding and Decoding

``` r

library(punycoder)

# Encode Unicode domains to ASCII
puny_encode("café.com")
# Returns: "xn--caf-dma.com"

puny_encode("москва.рф")
# Returns: "xn--80adxhks.xn--p1ai"

# Decode ASCII domains back to Unicode
puny_decode("xn--caf-dma.com")
# Returns: "café.com"

# Vectorized operations
domains <- c("café.com", "москва.рф", "北京.中国")
encoded <- puny_encode(domains)
print(encoded)
```

#### URL Processing

``` r

# Encode URLs with Unicode domains
url_encode(paste0("https", "://", "café.example.com/menu"))

# Decode URLs back to Unicode
url_decode(paste0("https", "://", "xn--caf-dma.example.com/menu"))

# Parse URLs with IDN handling
url_parts <- parse_url(
  paste0("https", "://", "café.example.com:8080/path?q=test#section")
)
print(url_parts)
```

#### Validation and Utilities

``` r

# Check if domain is already punycode
is_punycode("xn--caf-dma.com") # TRUE
is_punycode("café.com") # FALSE

# Check if domain contains Unicode characters
is_idn("café.com") # TRUE
is_idn("example.com") # FALSE

# Comprehensive domain validation
result <- validate_domain(c("café.com", "invalid..domain", "valid.org"))
print(result)
```

### Data Analysis Workflows

#### Web Scraping with International Domains

``` r

# Example: Processing international URLs for web scraping
international_hosts <- c("café.paris.fr", "москва.рф", "北京.中国")
international_paths <- c("/menu", "/news", "/info")
international_urls <- paste0(
  "https",
  "://",
  international_hosts,
  international_paths
)

# Convert to ASCII for HTTP requests
ascii_urls <- url_encode(international_urls)
print(ascii_urls)

# Process the data...

# Convert back to Unicode for display
display_urls <- url_decode(ascii_urls)
print(display_urls)
```

#### Bulk Domain Processing

``` r

# Example: Processing large datasets
set.seed(123)
sample_domains <- c(
  rep("example.com", 1000),
  rep("café.com", 1000),
  rep("test.org", 1000)
)

# Efficient vectorized encoding
system.time({
  encoded_domains <- puny_encode(sample_domains)
})

# Check results
table(is_punycode(encoded_domains))
```

### Error Handling

The package provides robust error handling with informative messages:

``` r

# Strict validation (default)
try({
  puny_encode(c("valid.com", "")) # Empty string causes error
})

# Non-strict mode returns NA for invalid input
result <- puny_encode(c("valid.com", ""), strict = FALSE)
print(result)

# Validation provides detailed error information
validation <- validate_domain(c("valid.com", "invalid..domain", ""))
print(validation)
```

### Performance Considerations

The package is designed for high-performance processing:

- **Vectorized operations**: Process thousands of domains efficiently
- **C++ backend**: Native implementation for speed
- **Memory efficient**: Handles large datasets without excessive memory
  use

``` r

# Benchmark with large dataset
large_domains <- rep(c("example.com", "café.com"), 5000)

system.time({
  encoded <- puny_encode(large_domains)
})

# Should process 10,000+ domains per second
```

### Package Options

You can configure package behavior using R options:

``` r

# Set global strict validation
options(punycoder.strict = FALSE)

# Check current setting
getOption("punycoder.strict")

# Set encoding preference
options(punycoder.encoding = "UTF-8")
```

### Integration with Other Packages

`punycoder` is designed to integrate well with other R packages:

``` r

# With data.table
library(data.table)
dt <- data.table(
  original = c("café.com", "москва.рф"),
  encoded = puny_encode(c("café.com", "москва.рф"))
)

# With dplyr
library(dplyr)
urls_df <- data.frame(
  unicode_url = paste0("https", "://", c("café.com", "москва.рф"))
) |>
  mutate(
    ascii_url = url_encode(unicode_url),
    is_international = is_idn(unicode_url)
  )
```

### Next Steps

- Explore the function documentation:
  [`help(package = "punycoder")`](https://bart-turczynski.github.io/punycoder/reference)
- Check out the test suite for more examples
- Report issues at:
  <https://github.com/bart-turczynski/punycoder/issues>

### Technical Details

The package uses a C++ backend with Rcpp for performance, and follows
RFC 3492 standards for punycode implementation. When `libidn2` is
available at build time, `punycoder` uses it behind the same R-level API
and falls back to the built-in implementation otherwise.

### See also

`punycoder` is used as the Punycode and IDNA engine by two sibling
packages:

- **[pslr](https://bart-turczynski.github.io/pslr/)** — Public Suffix
  List engine. Uses `punycoder` for host canonicalization before PSL
  matching. Reach for it when you need eTLD or registrable-domain
  queries.
- **[rurl](https://bart-turczynski.github.io/rurl/)** — Full URL
  parsing, normalization, cleaning, and joining toolkit. Builds on both
  `punycoder` and `pslr` to handle the complete URL processing pipeline.

### Acknowledgments

`punycoder` descends from the earlier R
[hrbrmstr/punycode](https://github.com/hrbrmstr/punycode) package and
implements published standards directly: RFC 3492 (Punycode), the
IDNA2008 RFCs, Unicode UTS \#46, and UAX \#15 normalization, validated
against the Unicode Consortium’s IdnaTestV2 conformance data. It is
built on `Rcpp` with an optional GNU libidn2 backend.

The full list of credits — prior art, dependencies, the standards this
code implements, and the data sources it serves — is in
[`ACKNOWLEDGMENTS.md`](https://github.com/bart-turczynski/punycoder/blob/main/ACKNOWLEDGMENTS.md).
