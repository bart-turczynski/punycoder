# Package index

## Host Normalization

Entry point for UTS#46 IDNA host normalization — maps a hostname to a
canonical lowercase ASCII comparison form.

- [`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
  : Normalize hosts to canonical comparison form
- [`normalization_profile_info()`](https://bart-turczynski.github.io/punycoder/reference/normalization_profile_info.md)
  : Canonical-host normalization profile identity

## Punycode Codec

Low-level RFC 3492 encoder/decoder for individual domain labels (`xn--`
ASCII-Compatible Encoding).

- [`puny_encode()`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md)
  : Encode Unicode domain labels to ASCII Punycode (low-level)
- [`puny_decode()`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md)
  : Decode ASCII Punycode to Unicode domain labels (low-level)

## Validators

Predicates for classifying domain names and labels.

- [`validate_domain()`](https://bart-turczynski.github.io/punycoder/reference/validate_domain.md)
  : Comprehensive domain name validation
- [`is_idn()`](https://bart-turczynski.github.io/punycoder/reference/is_idn.md)
  : Test if domain contains internationalized characters
- [`is_punycode()`](https://bart-turczynski.github.io/punycoder/reference/is_punycode.md)
  : Test if string is punycode encoded

## Deprecated URL Helpers

Best-effort URL host extraction and rewriting. Deprecated in favour of
dedicated URL packages.

- [`url_encode()`](https://bart-turczynski.github.io/punycoder/reference/url_encode.md)
  : Best-effort host rewriting in a URL-shaped string (Unicode host to
  ASCII)
- [`url_decode()`](https://bart-turczynski.github.io/punycoder/reference/url_decode.md)
  : Best-effort host rewriting in a URL-shaped string (ASCII punycode to
  Unicode)
- [`parse_url()`](https://bart-turczynski.github.io/punycoder/reference/parse_url.md)
  : Best-effort host extraction from a URL-shaped string

## Internals

S3 print methods and package overview.

- [`punycoder`](https://bart-turczynski.github.io/punycoder/reference/punycoder-package.md)
  [`punycoder-package`](https://bart-turczynski.github.io/punycoder/reference/punycoder-package.md)
  : Unicode and Punycode Domain Name Processing
- [`print(`*`<punycoder_parsed_url>`*`)`](https://bart-turczynski.github.io/punycoder/reference/print.punycoder_parsed_url.md)
  : Print method for punycoder parsed URL results
- [`print(`*`<punycoder_validation>`*`)`](https://bart-turczynski.github.io/punycoder/reference/print.punycoder_validation.md)
  : Print method for punycoder validation results
