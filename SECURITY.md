# Security Policy

## Supported versions

`punycoder` is distributed through CRAN. Security fixes are made against
the latest released version; please upgrade to the most recent release
before reporting.

| Version                     | Supported |
|-----------------------------|-----------|
| Latest CRAN release (1.2.x) | ✅        |
| Older releases              | ❌        |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub
issues.**

Preferred channel — **GitHub private vulnerability reporting**:

1.  Go to the repository’s **Security** tab.
2.  Click **Report a vulnerability**.

This opens a private security advisory visible only to the maintainers.

If you cannot use that channel, email the maintainer at
**<bartek@turczynski.pl>** instead.

## What to expect

- We aim to acknowledge a report within **7 days**.
- We will investigate, work on a fix, and coordinate disclosure with
  you.
- We are happy to credit reporters in the release notes unless you
  prefer to remain anonymous.

## Scope

`punycoder` is a C/C++ and R library for RFC 3492 Punycode
encoding/decoding and UTS \#46 IDNA host normalization. It makes no
network connections of its own and handles no credentials. Its security
surface is the safe handling of untrusted Punycode and internationalized
domain name input, including the C/C++ codec core (buffer handling,
UTF-8 decoding, and domain label parsing).
