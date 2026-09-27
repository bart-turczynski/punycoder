#!/bin/sh
# Verbatim body of the former standalone `news-version` CI job (SEOR-pgammbgo),
# its two script blocks concatenated in their original order. Each block kept
# its own `set -eu` in the original job because each ran as a separate GitLab
# `script:` item; re-setting it here per block is a harmless no-op, and
# concatenating them into one shell script reproduces the original control
# flow exactly -- an `exit` in block 1 stops the script before block 2 runs,
# the same as a failing script item stopping the job before the next one.

set -eu
version="$(grep -E '^Version:' DESCRIPTION | head -n1 | sed -E 's/^Version:[[:space:]]*//')"
heading="$(grep -m1 -E '^# ' NEWS.md | sed -E 's/^#[[:space:]]+punycoder[[:space:]]*//')"
echo "DESCRIPTION Version : '$version'"
echo "Top NEWS heading    : '$heading'"
if [ "$heading" = "(development version)" ] || [ "$heading" = "$version" ]; then
  echo "OK: NEWS heading and version are consistent."
else
  echo "ERROR: top NEWS.md heading ('$heading') is neither '(development version)' nor the DESCRIPTION Version ('$version'). Update NEWS.md before release."
  exit 1
fi

set -eu
version="$(grep -E '^Version:' DESCRIPTION | head -n1 | sed -E 's/^Version:[[:space:]]*//')"
case "$version" in
  *.9000)
    echo "Development version ('$version'); release paperwork not checked."
    exit 0
    ;;
esac

status=0

zenodo="$(grep -E '"version"' .zenodo.json | head -n1 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
if [ "$zenodo" = "$version" ]; then
  echo "OK: .zenodo.json version is '$zenodo'."
else
  echo "ERROR (.zenodo.json): version ('$zenodo') does not match the DESCRIPTION Version ('$version')."
  status=1
fi

if grep -q "tags/v$version\$" _pkgdown.yml; then
  echo "OK: _pkgdown.yml links the v$version release."
else
  echo "ERROR (_pkgdown.yml): does not link the v$version release tag. Update the news.releases entry."
  status=1
fi

exit "$status"
