# Unicode and Punycode Domain Name Processing

Provides high-performance functions for processing internationalized
domain names, split across two tiers.

## Details

The package exposes two distinct surfaces, deliberately kept separate:

- A **low-level Punycode codec**
  ([`puny_encode()`](https://bart-turczynski.github.io/punycoder/reference/puny_encode.md)
  /
  [`puny_decode()`](https://bart-turczynski.github.io/punycoder/reference/puny_decode.md)):
  the raw RFC 3492 transform with `xn--` A-label framing (RFC 5890/5891)
  and letter-digit-hyphen checks. It performs no Unicode normalization.

- An **IDNA/UTS-46 host-normalization surface**
  ([`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)):
  Unicode NFC, UTS \#46 mapping and validation, and conversion to a
  canonical lowercase ASCII comparison form under a pinned profile.

Use the codec when you need the literal ASCII-Compatible Encoding of a
label; use
[`host_normalize()`](https://bart-turczynski.github.io/punycoder/reference/host_normalize.md)
when you need a standards-profiled comparison form for a host name.

## See also

Useful links:

- <https://bart-turczynski.github.io/punycoder/>

- <https://github.com/bart-turczynski/punycoder>

- <https://bart-turczynski.r-universe.dev/punycoder>

- <https://CRAN.R-project.org/package=punycoder>

- Report bugs at <https://github.com/bart-turczynski/punycoder/issues>

## Author

**Maintainer**: Bart Turczynski <bartek@turczynski.pl>
([ORCID](https://orcid.org/0000-0002-8788-7980))

Authors:

- Bart Turczynski <bartek@turczynski.pl>
  ([ORCID](https://orcid.org/0000-0002-8788-7980))
