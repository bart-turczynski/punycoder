# Security Policy

## Supported versions

`punycoder` is distributed through CRAN. Security fixes are made against the
latest released version; please upgrade to the most recent release before
reporting.

| Version              | Supported          |
| -------------------- | ------------------ |
| Latest CRAN release  | :white_check_mark: |
| Older releases       | :x:                |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public issues.**

Preferred channel — **email the maintainer at bartek@turczynski.pl.**

Alternatively, open a **confidential issue** on the GitLab project:

1. Go to [Issues](https://gitlab.com/bart-turczynski/punycoder/-/work_items) and click
   **New issue**.
2. Tick **This issue is confidential** before submitting.

A confidential issue is visible only to you, its assignees and the project
members whose role lets them see confidential issues.

Email is listed first deliberately: it works whether or not you have a GitLab
account, and it is the channel the maintainer monitors.

Do not include secrets, credentials, tokens, or private customer data in a
report, an issue, a merge request or a log.

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
