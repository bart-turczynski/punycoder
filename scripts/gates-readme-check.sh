#!/bin/sh
# Body of the former standalone `readme` CI job's diff-check line
# (SEOR-pgammbgo). Runs after `devtools::build_readme()` has re-knit
# README.md; fails if the result drifts from what is committed.
#
# Blank-line-only differences don't count: pandoc versions disagree about the
# blank line after `<!-- badges: start -->`, so a README rendered with a newer
# local pandoc would pass pre-push and fail here. The test is on the diff's
# output, not `--exit-code`: rocker's git 2.43 still exits 1 on a blank-only
# diff under --ignore-blank-lines (SEOR-kaqtnovh).
readme_diff=$(git diff --ignore-blank-lines -- README.md)
if [ -n "$readme_diff" ]; then
  printf '%s\n' "$readme_diff"
  echo "ERROR: README.md is out of sync with README.Rmd."
  echo "Run devtools::build_readme() and commit the result."
  exit 1
fi
