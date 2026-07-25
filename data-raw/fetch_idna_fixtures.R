#!/usr/bin/env Rscript
#
# Fetch the official UTS #46 conformance corpus (IdnaTestV2.txt) for every
# Unicode version punycoder ships a table set for, and vendor one copy per
# version under inst/testdata/.
#
# Run from the package root:  Rscript data-raw/fetch_idna_fixtures.R
#
# Network access happens HERE, at generation time only, exactly as in
# data-raw/generate_unicode_tables.R. The vendored corpora are committed; the
# package never downloads anything at build, check, or run time. Downloads are
# cached under data-raw/.idna-cache/<version>/ (git-ignored) -- keyed by
# version, because the file NAME is identical across versions and a flat cache
# would silently serve one version's corpus to another version's run.
#
# Each corpus is copied VERBATIM: the expectations are only meaningful as the
# bytes Unicode published, and the parser in tests/testthat/helper-idna.R reads
# the upstream format directly. Nothing here rewrites or filters the file.

# The versions to vendor. Kept in sync with PUNYCODER_UNICODE_VERSIONS in
# src/punycoder_unicode_version.h -- i.e. with what unicode_versions() reports.
# Adding a table set means adding it here and re-running this script.
unicode_versions <- c("16.0.0", "17.0.0")

# Every output name derives from the version string alone, in the same
# derived-not-hand-written spirit as the table generator (ADR-011/ADR-012). The
# DOTTED form is used verbatim in the filename so a test can build the path from
# unicode_versions() with no translation step.
fixture_path <- function(version) {
  file.path("inst", "testdata", sprintf("IdnaTestV2-%s.txt", version))
}

# The IDNA directory MOVED in Unicode 17: Public/idna/<ver> became
# Public/<ver>/idna. Both layouts are tried, newest-first, so this script can
# still fetch a <=16.0.0 corpus. Deliberately NOT Public/idna/latest/ -- which
# is byte-identical to the current release but would defeat the entire point of
# vendoring a pinned version.
idna_bases <- function(version) {
  c(
    sprintf("https://www.unicode.org/Public/%s/idna", version),
    sprintf("https://www.unicode.org/Public/idna/%s", version)
  )
}

fetch <- function(name, base, cache_dir) {
  dest <- file.path(cache_dir, name)
  if (!file.exists(dest)) {
    ok <- FALSE
    for (b in base) {
      url <- sprintf("%s/%s", b, name)
      message("downloading ", url)
      ok <- tryCatch({
        utils::download.file(url, dest, mode = "wb", quiet = TRUE)
        TRUE
      }, error = function(e) {
        message("  failed: ", conditionMessage(e))
        FALSE
      })
      if (ok) break
      unlink(dest)
    }
    if (!ok) {
      stop(sprintf("could not fetch %s from any of: %s", name, toString(base)))
    }
  }
  dest
}

for (version in unicode_versions) {
  cache_dir <- file.path("data-raw", ".idna-cache", version)
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

  src <- fetch("IdnaTestV2.txt", idna_bases(version), cache_dir)
  dest <- fixture_path(version)

  # A corpus that arrives truncated or as an HTML error page would otherwise be
  # committed and then quietly weaken every conformance assertion, so sanity
  # check the shape before overwriting the vendored copy.
  lines <- readLines(src, encoding = "UTF-8", warn = FALSE)
  if (length(lines) < 6000L || !grepl("^# IdnaTestV2.txt", lines[[1L]])) {
    stop(sprintf("%s does not look like an IdnaTestV2 corpus (%d lines)",
                 src, length(lines)))
  }

  file.copy(src, dest, overwrite = TRUE)
  message(sprintf("wrote %s (%d lines, %s)", dest, length(lines),
                  sub("^#\\s*", "", lines[[2L]])))
}
