#!/usr/bin/env Rscript

# scripts/gates.R -- the consolidated "cheap" verify-stage checks
# (SEOR-pgammbgo).
#
# WHY. punycoder ran twelve CI jobs, and roughly 2 minutes of every job is
# pure runner-pickup tax (image pull, before_script, cache restore) that has
# nothing to do with how much work the job itself does. Three of them --
# `lint`, `readme`, `news-version` -- were each well under a minute of real
# checking, paying that tax three times over. This script folds them into
# one CI job (`gates`), which pays the tax once.
#
# `check`, `coverage`, `pages`, `full-check`, `sanitizers`, `osv-audit`, and
# `security-audit` stay separate jobs: each is a genuinely different failure
# meaning (build/test correctness, coverage regression, security finding,
# ...), not another instance of "the same kind of cheap check".
#
# Two other named candidates were rejected -- see the `gates:` job comment in
# .gitlab-ci.yml for both:
#   * `codemeta` is not part of the merge gate, and its own script line can
#     never fail, so it isn't a pass/fail check to fold in.
#   * `citation-version` runs stdlib-only Python on a dedicated
#     `python:3.13-alpine` image; the `rocker/r-ver` image this script runs
#     under has no python3 at all (verified directly against the image, not
#     assumed), so it stayed its own job rather than paying for an apt-get
#     python3 on every merge forever.
#
# BINDING CONDITION, ported from rurl's tools/verify.R "accumulate, then
# report" shape (its `results` list and final `VERDICT: FAIL -- <labels>`
# line): every check below runs REGARDLESS of an earlier one failing. Each
# records its own PASS/FAIL. Only after every check has run does this script
# print ONE summary naming every check's verdict, and only THEN does it
# exit nonzero if any failed. A fail-fast harness that stopped at the first
# red check would gut the point of the fold: independent signals
# collapsed into one that still needed N re-runs to find the Nth failure.
#
# Every check below that was once a standalone CI job reproduces, as close to
# verbatim as an R harness allows, the `script:` lines that job ran before
# this fold. `spelling` and `docs-drift` never were jobs; each runs the same
# command as its pre-push counterpart. The before/after command enumeration
# lives in the commit message that introduced this file, not here, so it
# cannot drift out of sync with what actually landed. This script does not
# install any dependency itself -- that is the `gates` CI job's own
# `before_script`/`script` setup (pak, apt packages, pandoc), same as none of
# rurl's tools/verify.R stages install packages either. Run from the package
# root.

Sys.setenv(LINTR_ERROR_ON_LINT = "true")

# One subprocess, output captured to a temp log (never to the console
# directly, so a passing check's noise does not bury a later failure's
# signal -- only failed checks print their log below).
run_cmd <- function(command, args = character(0)) {
  log <- tempfile(fileext = ".log")
  status <- suppressWarnings(system2(command, args, stdout = log, stderr = log))
  list(ok = identical(as.integer(status), 0L), log = readLines(log, warn = FALSE))
}

# A "check" is one or more subprocess calls run IN ORDER, stopping at the
# first failure -- the same as GitLab running a job's `script:` lines
# sequentially and failing the whole job at the first nonzero line. This is
# what lets `readme` and `news-version`, each formerly 2 script lines, fold
# in as a single named PASS/FAIL each.
run_check <- function(label, ...) {
  substeps <- list(...)
  for (sub in substeps) {
    res <- sub()
    if (!res$ok) {
      return(list(label = label, ok = FALSE, log = res$log))
    }
  }
  list(label = label, ok = TRUE, log = character(0))
}

results <- list()

# --- lint ---------------------------------------------------------------
# was: Rscript -e 'lintr::lint_package()'   (LINTR_ERROR_ON_LINT=true set
# above converts any lint into a nonzero exit, same as the job `variables:`)
results$lint <- run_check(
  "lint",
  function() run_cmd("Rscript", c("-e", shQuote("lintr::lint_package()")))
)

# --- readme ---------------------------------------------------------------
# was:
#   Rscript -e 'devtools::build_readme()'
#   if ! git diff --exit-code -- README.md; then ...; exit 1; fi
results$readme <- run_check(
  "readme",
  function() run_cmd("Rscript", c("-e", shQuote("devtools::build_readme()"))),
  function() run_cmd("sh", "scripts/gates-readme-check.sh")
)

# --- news-version -----------------------------------------------------------
# was the news-version job's two script blocks; see
# scripts/gates-news-version.sh, a verbatim copy of both.
results[["news-version"]] <- run_check(
  "news-version",
  function() run_cmd("sh", "scripts/gates-news-version.sh")
)

# --- spelling ---------------------------------------------------------------
# The fleet standard puts a spelling gate on every push to main (seor
# design/fleet-standard.md). Same command as the pre-push `spelling` hook in
# .pre-commit-config.yaml; genuine terms go in inst/WORDLIST.
results$spelling <- run_check(
  "spelling",
  function() {
    run_cmd("Rscript", c("-e", shQuote(paste(
      "bad <- spelling::spell_check_package();",
      "if (nrow(bad)) { print(bad); quit(status = 1) }"
    ))))
  }
)

# --- docs-drift -------------------------------------------------------------
# The pre-push gate's docs-drift step (SEOR-nwfmerhu): regenerate man/ and
# NAMESPACE with roxygen2 and fail on any difference from what is committed,
# since a stale .Rd is valid .Rd and neither lint nor R CMD check sees it. Same
# `git archive HEAD` export as scripts/verify-on-push.sh, so the pkgload
# compile roxygen runs never writes build products into this checkout. The
# roxygen2 pin it needs is installed by the `gates` CI job.
docs_tar <- tempfile("docs-drift-", fileext = ".tar")
docs_dir <- tempfile("docs-drift-")
dir.create(docs_dir)
results[["docs-drift"]] <- run_check(
  "docs-drift",
  function() {
    run_cmd("git", c("archive", paste0("--output=", shQuote(docs_tar)), "HEAD"))
  },
  function() {
    run_cmd("tar", c("-xf", shQuote(docs_tar), "-C", shQuote(docs_dir)))
  },
  function() {
    run_cmd("Rscript", c("scripts/check-docs-drift.R", shQuote(docs_dir)))
  }
)
unlink(c(docs_tar, docs_dir), recursive = TRUE)

for (r in results) {
  cat(sprintf("=== [%s] %s ===\n", if (r$ok) "PASS" else "FAIL", r$label))
  if (length(r$log)) {
    cat(paste0("  | ", r$log, collapse = "\n"), "\n", sep = "")
  }
}

failed <- Filter(function(r) !r$ok, results)
cat(sprintf("\n%d gate(s) run, %d failed\n", length(results), length(failed)))
if (length(failed)) {
  cat("VERDICT: FAIL --",
      paste(vapply(failed, function(r) r$label, character(1)), collapse = ", "),
      "\n")
  quit(status = 1)
}
cat("VERDICT: PASS -- all", length(results), "gates green\n")
quit(status = 0)
