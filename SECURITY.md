# Security Policy

## Supported versions

`punycoder` is distributed through CRAN. Security fixes are made against the
latest released version; please upgrade to the most recent release before
reporting.

| Version                     | Supported          |
| --------------------------- | ------------------ |
| Latest CRAN release (1.2.x) | :white_check_mark: |
| Older releases              | :x:                |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public issues.**

Preferred channel — **email the maintainer** at **bartek@turczynski.pl**.
Include the affected version, a reproducer if you have one, and how you would
like to be credited.

If you would rather use the tracker, open a **confidential issue** on GitLab:

1. Go to <https://gitlab.com/bart-turczynski/punycoder/-/work_items/new>.
2. Tick **This issue is confidential** before submitting.

A confidential issue is visible only to the project maintainers, not to other
users or to the public.

> This project moved off GitHub, so GitHub's private vulnerability reporting
> (private security advisories) is no longer a channel for it. GitLab's own
> private-vulnerability-reporting feature is not available on this project's
> plan; confidential issues are the equivalent confidential channel here.

## What to expect

- We aim to acknowledge a report within **7 days**.
- We will investigate, work on a fix, and coordinate disclosure with you.
- We are happy to credit reporters in the release notes unless you prefer to
  remain anonymous.

## Scope

`punycoder` is a C/C++ and R library for RFC 3492 Punycode encoding/decoding
and UTS #46 IDNA host normalization. It makes no network connections of its own
and handles no credentials. Its security surface is the safe handling of
untrusted Punycode and internationalized domain name input, including the C/C++
codec core (buffer handling, UTF-8 decoding, and domain label parsing).
