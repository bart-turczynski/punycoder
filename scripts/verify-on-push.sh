#!/usr/bin/env bash
#
# pre-push entry point for the verify gate (PUNY-dopcsyjw). Ported from rurl's
# tools/verify-on-push.sh (RURL-qkowfsdt); the predicate is rurl's, verbatim.
#
# WHY THIS EXISTS. `.pre-commit-config.yaml` used to spell the pre-push hook
# inline as `entry: Rscript -e '<lintr + rcmdcheck>'` with `always_run: true`
# and no predicate, so the full gate fired for EVERY destination -- including
# `git push backup`, whose target is the local bare mirror at
# ~/Projects/_backups/punycoder.git. Running the gate there verifies nothing
# (the mirror only ever receives history that already passed on its way to
# `origin`) and costs minutes of lintr plus `R CMD check --as-cran`. What kept
# it from running was a sentence in AGENTS.md telling people to push to
# `backup` with `--no-verify`, and a gate that fires where it cannot help is a
# gate people learn to `--no-verify` past -- including where it can.
#
# (rurl had a third reason: its gate rewrites tests/testthat/_snaps/ and so
# dirties the tree on an archival push. That does not apply here; punycoder
# has no snapshot tests and a gate run leaves `git status` clean.)
#
# So: skip for a mirror, run unchanged for a forge. `always_run` stays -- the
# missing predicate was the remote, not the file set.
#
# THE PREDICATE: is the destination a directory on THIS filesystem?
#
# Not the remote NAME. A name is a local alias; `backup` is what this clone
# happens to call the mirror today and anyone can rename it, so keying on the
# string would leave the skip silently attached to the wrong remote after a
# `git remote rename`. The URL is the thing that says where the objects land,
# so test that instead:
#
#   -d "$url"  ->  a path on this machine  ->  a mirror  ->  skip
#   otherwise  ->  a transport (ssh/https/git)  ->  a forge  ->  run the gate
#
# `git@gitlab.com:bart-turczynski/punycoder.git` is not a directory;
# `/Users/.../_backups/punycoder.git` is. One readable test, and it generalizes
# to a second mirror without editing this file.
#
# WHY THERE IS NO `github` CASE. The GitHub repository is a read-only mirror of
# the GitLab one, and GitLab's push mirror, which runs server-side, is its only
# writer. The policy that follows is that no working copy has a local `github`
# remote, so no push from this machine targets GitHub and there is nothing to
# special-case. A `github` remote added anyway would carry a network URL, not
# a directory, and so would be gated like `origin`.
#
# FAILING OPEN MEANS RUNNING. Every path that cannot positively identify a local
# mirror runs the full gate: no arguments (a hand-run
# `pre-commit run --hook-stage pre-push` passes none), an empty URL, an
# unrecognized shape. A missed skip costs minutes; a missed gate ships
# unverified work.
#
# Usage:
#   scripts/verify-on-push.sh                  # no remote known -> run the gate
#   scripts/verify-on-push.sh <name> <url>     # as git calls a pre-push hook
#
# Arguments are optional because both callers exist. Git hands a pre-push hook
# `$1`=remote name and `$2`=remote URL, but pre-commit does NOT forward them to
# a hook `entry` -- it consumes them itself and re-exports them as
# `PRE_COMMIT_REMOTE_NAME` / `PRE_COMMIT_REMOTE_URL`. The environment is
# therefore the live path; the positional form is what makes the predicate
# testable by hand, without pushing anything.
#
# THE GATE ITSELF is the command the inline hook ran, byte for byte: lintr,
# then `R CMD check --as-cran` failing on any WARNING, mirroring CI.
#
# THE DOCS-DRIFT STEP runs first (SEOR-nwfmerhu): scripts/check-docs-drift.R
# regenerates man/ and NAMESPACE with roxygen2 and fails, printing the diff,
# when they differ from what is committed. A stale .Rd is still valid .Rd, so
# neither lintr nor R CMD check can see it. It runs on its OWN `git archive
# HEAD` export, never on this working tree: roxygen loads the package through
# pkgload, which runs ./configure and compiles src/ in place, and those build
# products would land in the directory rcmdcheck builds from below. HEAD, not
# the working tree, because HEAD is what the push sends. The `docs-drift`
# check in scripts/gates.R runs the same two commands in CI.
#
# THE EXIT-STATUS GUARD after the check: rcmdcheck reads a check that halted
# partway as 0/0/0 and returns normally, so error_on never fires. The gate
# also fails on R CMD check's own exit status (SEOR-maavnxdm).

set -euo pipefail

REMOTE_NAME="${1-${PRE_COMMIT_REMOTE_NAME-}}"
REMOTE_URL="${2-${PRE_COMMIT_REMOTE_URL-}}"

if [ -n "$REMOTE_URL" ] && [ -d "$REMOTE_URL" ]; then
  echo "verify: skipped -- '${REMOTE_NAME:-?}' is a local path ($REMOTE_URL), i.e. an archival mirror, not a forge; the gate runs on the push to origin. Force it with: scripts/verify-on-push.sh"
  exit 0
fi

# The export is removed by hand before `exec`, which replaces this shell and so
# never fires an EXIT trap; the trap covers a failing step.
docsdir="$(mktemp -d)"
trap 'rm -rf "$docsdir"' EXIT
git archive HEAD | tar -x -C "$docsdir"
Rscript scripts/check-docs-drift.R "$docsdir"
rm -rf "$docsdir"
trap - EXIT

exec Rscript -e 'lints <- lintr::lint_package(); if (length(lints)) { print(lints); quit(status = 1) }; res <- rcmdcheck::rcmdcheck(args = "--as-cran", error_on = "warning"); if (!identical(as.integer(res$status), 0L)) stop("R CMD check exited with status ", res$status, "; the run did not complete.", call. = FALSE)'
