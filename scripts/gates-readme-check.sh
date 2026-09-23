#!/bin/sh
# Verbatim body of the former standalone `readme` CI job's diff-check line
# (SEOR-pgammbgo). Runs after `devtools::build_readme()` has re-knit
# README.md; fails if the result drifts from what is committed.
if ! git diff --exit-code -- README.md; then
  echo "ERROR: README.md is out of sync with README.Rmd."
  echo "Run devtools::build_readme() and commit the result."
  exit 1
fi
