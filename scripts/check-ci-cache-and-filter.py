# check-ci-cache-and-filter v1
"""Pin two facts about `.gitlab-ci.yml` that are easy to get silently wrong.

WHY THIS EXISTS (SEOR-dyzgzyot, SEOR-wqxhftpv).

1. THE CACHE. The `.r:` template sets `R_LIBS_USER` and caches `.Rlibs/`, but
   setting the variable is not sufficient by itself: rocker/r-ver's
   `Renviron.site` defaults `R_LIBS` (not `R_LIBS_USER`) to
   `site-library:library` whenever `R_LIBS` itself is unset, and that default
   wins over `R_LIBS_USER` at session start. Verified directly against the
   image this pipeline uses:

       $ docker run --rm -e R_LIBS_USER=/tmp/rlib rocker/r-ver:4.5.1 \\
           Rscript -e '.libPaths()'
       [1] "/usr/local/lib/R/site-library" "/usr/local/lib/R/library"

   -- the cache directory does not even appear. Packages installed during the
   job land in the image's site-library and vanish with the container; the
   cache then faithfully preserves an empty `.Rlibs/` every run (seor measured
   this exact failure: `.r-lib` 1 entry, 0.0 MiB). The fix -- appending to
   `Rprofile.site`, which is read late enough to win -- is proven the same way:

       $ docker run --rm -e R_LIBS_USER=/tmp/rlib rocker/r-ver:4.5.1 sh -c '
           mkdir -p /tmp/rlib
           echo ".libPaths(c(Sys.getenv(\\"R_LIBS_USER\\"), .libPaths()))" \\
             >> "${R_HOME}/etc/Rprofile.site"
           Rscript -e ".libPaths()"'
       [1] "/tmp/rlib"                     "/usr/local/lib/R/site-library"
       [3] "/usr/local/lib/R/library"

   Site-library stays reachable (so the image's own docopt/littler keep
   resolving) but now sits BEHIND the cache dir, which is what makes R install
   new packages into the cached path instead of the image.

2. THE PKGDOWN FILTER. `pkgdown:::package_mds()` hardcodes a skip list
   (README/NEWS/LICENSE) and renders every other top-level `.md` as a page,
   so `_pkgdown.yml` has no setting that can exclude one. A glob such as
   `rm -f AGENTS*.md CLAUDE*.md FP_*.md` only widens as agent-file FAMILIES
   are added by hand and stays fail-open for the next unnamed one (e.g.
   `GEMINI.md`). A keep-list is fail-closed: an unrecognized file defaults to
   private (moved out, per pslr's `mv`-not-`rm` precedent -- deleting leaves
   `search.json` pointing at pages that 404).

WHAT THIS CHECKS. Both checks are snapshot pins, not open-ended policy: each
reads what `.gitlab-ci.yml` and the repository's real top-level `*.md` files
actually produce today, and compares that against an explicit expected value
below. A pin going red means either a regression (fix a real drift) or an
intentional change (update the expected value in the same commit that made
the change, the way NEWS.md snapshots are re-recorded deliberately).

    python3 scripts/check-ci-cache-and-filter.py              # exit 1 on drift
    python3 scripts/check-ci-cache-and-filter.py --self-test  # positive/negative cases
"""

from __future__ import annotations

import fnmatch
import re
import sys
import tempfile
from pathlib import Path

# ---------------------------------------------------------------------------
# .gitlab-ci.yml parsing -- deliberately not a YAML parser. This file is
# hand-authored with a plain anchor (`.pandoc_script: &pandoc_script`, see the
# comment above it) specifically so a safe loader can parse it, but the
# checks here only need two narrow slices (one job's `before_script:` /
# `script:` block), so a small indentation-aware extractor keeps this stdlib
# only, matching check-citation.py's rationale for the same choice.
# ---------------------------------------------------------------------------


def _extract_block(text: str, top_key: str, sub_key: str) -> list[str]:
    """Lines of `sub_key:`'s list, nested under the top-level `top_key:`.

    `top_key` is matched at column 0 (e.g. ``".r:"`` or ``"pages:"``); the
    block extends to the next column-0, non-blank line. `sub_key` is matched
    at one level of indentation inside it (e.g. ``"before_script:"``); its
    list items are every following line indented deeper than `sub_key`
    itself, stopping at the first line that is not.
    """
    lines = text.splitlines()
    top_pattern = re.compile(r"^" + re.escape(top_key) + r"\s*$")
    start = next(
        (i for i, line in enumerate(lines) if top_pattern.match(line)), None
    )
    if start is None:
        return []
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i] and not lines[i][0].isspace():
            end = i
            break
    block = lines[start:end]

    sub_pattern = re.compile(r"^(\s+)" + re.escape(sub_key) + r"\s*:\s*$")
    sub_start = None
    sub_indent = None
    for i, line in enumerate(block):
        m = sub_pattern.match(line)
        if m:
            sub_start = i + 1
            sub_indent = len(m.group(1))
            break
    if sub_start is None:
        return []
    out = []
    for line in block[sub_start:]:
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        if indent <= sub_indent:
            break
        out.append(line)
    return out


# ---------------------------------------------------------------------------
# Check 1: the cached-library fix.
# ---------------------------------------------------------------------------

# Matches the exact append this fix requires -- see the module docstring for
# why it must be Rprofile.site, not R_LIBS_SITE or an environment variable.
LIBPATHS_APPEND = re.compile(
    r"""\.libPaths\(\s*c\(\s*Sys\.getenv\(\s*["']R_LIBS_USER["']\s*\)\s*,\s*\.libPaths\(\)\s*\)\s*\)"""
)
RPROFILE_SITE_TARGET = re.compile(r"""Rprofile\.site""")


def simulate_libpaths(before_script: list[str]) -> tuple[str, ...]:
    """The `.libPaths()` order this `before_script` produces, modeled from the
    verified rocker/r-ver behavior in the module docstring: `Renviron.site`
    defaults to site-library ahead of library whenever `R_LIBS` is unset, and
    an `Rprofile.site` append of the documented shape prepends the cache dir
    ahead of that -- because `Rprofile.site` is evaluated after
    `Renviron.site`.
    """
    appended = any(
        LIBPATHS_APPEND.search(line) and RPROFILE_SITE_TARGET.search(line)
        for line in before_script
    )
    site_default: tuple[str, ...] = ("site-library", "library")
    if appended:
        return ("R_LIBS_USER-cache",) + site_default
    return site_default


def check_libpaths(root: Path, expected_order: tuple[str, ...]) -> list[str]:
    ci_path = root / ".gitlab-ci.yml"
    if not ci_path.exists():
        return [".gitlab-ci.yml is missing"]
    before_script = _extract_block(
        ci_path.read_text(encoding="utf-8"), ".r:", "before_script"
    )
    if not before_script:
        return ["could not find `.r:` `before_script:` in .gitlab-ci.yml"]
    order = simulate_libpaths(before_script)
    if order != expected_order:
        return [
            "`.r:` before_script produces .libPaths() order "
            f"{order}, expected {expected_order}"
        ]
    return []


# ---------------------------------------------------------------------------
# Check 2: the pkgdown agent-file filter (glob today, keep-list after the
# fix). Both shapes are recognized so the same check pins the CI file's
# behavior before and after SEOR-wqxhftpv without being rewritten.
# ---------------------------------------------------------------------------

RM_GLOB_LINE = re.compile(r"^\s*-\s+['\"]?rm -f (.+?)['\"]?\s*$")
KEEP_ASSIGNMENT = re.compile(r'KEEP="([^"]*)"')


def simulate_md_survivors(script: list[str], md_files: set[str]) -> set[str]:
    """Which of `md_files` the `pages:` job's filter step would still publish.

    Recognizes two shapes:
      - a glob denylist: ``rm -f PATTERN PATTERN ...`` (pre SEOR-wqxhftpv)
      - a keep-list: a ``KEEP="a.md b.md ..."`` assignment feeding an
        mv-everything-else loop (post SEOR-wqxhftpv)

    An unrecognized script (neither shape found) raises, rather than silently
    reporting every file as a survivor -- a check that can't see the filter
    must not claim to have checked it.
    """
    joined = "\n".join(script)

    keep_match = KEEP_ASSIGNMENT.search(joined)
    if keep_match:
        keep = set(keep_match.group(1).split())
        return md_files & keep

    for line in script:
        m = RM_GLOB_LINE.match(line)
        if m:
            patterns = m.group(1).split()
            removed = {
                f for f in md_files if any(fnmatch.fnmatch(f, p) for p in patterns)
            }
            return md_files - removed

    raise ValueError(
        "pages: script matches neither the glob (`rm -f ...`) nor the "
        "keep-list (`KEEP=\"...\"`) shape -- update this check's parser"
    )


def check_md_filter(root: Path, expected_survivors: set[str]) -> list[str]:
    ci_path = root / ".gitlab-ci.yml"
    if not ci_path.exists():
        return [".gitlab-ci.yml is missing"]
    script = _extract_block(ci_path.read_text(encoding="utf-8"), "pages:", "script")
    if not script:
        return ["could not find `pages:` `script:` in .gitlab-ci.yml"]
    md_files = {p.name for p in root.glob("*.md")}
    try:
        survivors = simulate_md_survivors(script, md_files)
    except ValueError as exc:
        return [str(exc)]
    if survivors != expected_survivors:
        extra = survivors - expected_survivors
        missing = expected_survivors - survivors
        errors = []
        if extra:
            errors.append(
                f"pages: would publish {sorted(extra)}, not in the pinned "
                "keep set -- a new top-level .md leaked past the filter"
            )
        if missing:
            errors.append(
                f"pages: would no longer publish {sorted(missing)}, which "
                "the pin expects to survive"
            )
        return errors
    return []


# --- self-test (positive + negative coverage, executable) --------------------


def self_test() -> None:
    def repo(tag: str, ci_yaml: str, md_files: list[str]) -> Path:
        d = Path(tempfile.mkdtemp(prefix=f"cicheck-{tag}-"))
        (d / ".gitlab-ci.yml").write_text(ci_yaml, encoding="utf-8")
        for name in md_files:
            (d / name).write_text("x\n", encoding="utf-8")
        return d

    glob_ci = (
        ".r:\n"
        "  before_script:\n"
        "    - mkdir -p \"$R_LIBS_USER\"\n"
        "    - Rscript -e 'if (!requireNamespace(\"pak\")) install.packages(\"pak\")'\n"
        "\n"
        "pages:\n"
        "  script:\n"
        "    - apt-get update -qq\n"
        "    - 'rm -f AGENTS*.md CLAUDE*.md FP_*.md'\n"
        "    - Rscript -e 'pkgdown::build_site()'\n"
    )
    fixed_ci = (
        ".r:\n"
        "  before_script:\n"
        "    - mkdir -p \"$R_LIBS_USER\"\n"
        "    - echo '.libPaths(c(Sys.getenv(\"R_LIBS_USER\"), .libPaths()))' >> \"${R_HOME}/etc/Rprofile.site\"\n"
        "\n"
        "pages:\n"
        "  script:\n"
        "    - apt-get update -qq\n"
        "    - |\n"
        "      KEEP=\"README.md NEWS.md LICENSE.md\"\n"
        "      for f in *.md; do :; done\n"
        "    - Rscript -e 'pkgdown::build_site()'\n"
    )

    # POSITIVE: today's glob, today's file set -- the pin as it reads at
    # commit 1, before either fix lands.
    d = repo("glob-today", glob_ci, ["README.md", "NEWS.md", "AGENTS.md", "CLAUDE.md"])
    errs = check_md_filter(d, {"README.md", "NEWS.md"})
    assert not errs, f"expected clean, got {errs}"
    errs = check_libpaths(d, ("site-library", "library"))
    assert not errs, f"expected clean (no append yet), got {errs}"

    # NEGATIVE (md, "introduce a GEMINI.md"): the glob shape is fail-open --
    # a family it has never seen survives, and the pin (which still expects
    # only README/NEWS) must catch that as an unexpected extra survivor.
    d = repo(
        "glob-new-family",
        glob_ci,
        ["README.md", "NEWS.md", "AGENTS.md", "GEMINI.md"],
    )
    errs = check_md_filter(d, {"README.md", "NEWS.md"})
    assert any("GEMINI.md" in e for e in errs), f"expected GEMINI.md flagged, got {errs}"

    # POSITIVE (md, post SEOR-wqxhftpv): the keep-list shape closes the leak
    # -- GEMINI.md is swept away regardless of name.
    d = repo(
        "keep-list-new-family",
        fixed_ci,
        ["README.md", "NEWS.md", "LICENSE.md", "AGENTS.md", "GEMINI.md"],
    )
    errs = check_md_filter(d, {"README.md", "NEWS.md", "LICENSE.md"})
    assert not errs, f"expected clean, got {errs}"

    # NEGATIVE (libpaths, "strip the Rprofile.site append"): a before_script
    # that sets R_LIBS_USER but never appends to Rprofile.site is exactly
    # today's punycoder bug -- the pin must reject a claim that the cache dir
    # comes first when the append that makes that true is missing.
    d = repo("libpaths-stripped", glob_ci, ["README.md"])
    errs = check_libpaths(d, ("R_LIBS_USER-cache", "site-library", "library"))
    assert errs, "expected the pin to go RED with the append stripped"

    # POSITIVE (libpaths, fixed): the append restores the cache dir to the
    # front, site-library staying reachable behind it.
    d = repo("libpaths-fixed", fixed_ci, ["README.md"])
    errs = check_libpaths(d, ("R_LIBS_USER-cache", "site-library", "library"))
    assert not errs, f"expected clean, got {errs}"

    print("check-ci-cache-and-filter self-test: PASS (3 positive + 2 negative cases)")


# --- today's pinned expectations for THIS repository -------------------------
#
# Update these in the same commit that intentionally changes the CI file's
# behavior (a new keep-listed doc, a deliberately different .libPaths()
# order) -- same convention as check-citation.py and the README.md snapshot.
#
# As of SEOR-dyzgzyot / SEOR-wqxhftpv landing: the `pages:` job uses the
# keep-list (`mv`) shape, and `.r:` before_script appends to Rprofile.site so
# the cached library wins. Before those, this pinned the glob shape and the
# bug: survivors = every top-level .md except AGENTS/CLAUDE/FP_* (11 files,
# including ARCHITECTURE.md, DECISIONS.md, cran-comments.md -- see
# SPEC DELTA in the commit that changed this), and libpaths order =
# ("site-library", "library") with no cache dir at all.

PINNED_MD_SURVIVORS = {
    "README.md",
    "NEWS.md",
    "LICENSE.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "CODE_OF_CONDUCT.md",
    "THIRD_PARTY_NOTICES.md",
    "ACKNOWLEDGMENTS.md",
    "ARCHITECTURE.md",
    "DECISIONS.md",
    "cran-comments.md",
}

PINNED_LIBPATHS_ORDER = ("site-library", "library")


def main() -> int:
    if "--self-test" in sys.argv[1:]:
        self_test()
        return 0

    root = Path(__file__).resolve().parent.parent
    errors = check_md_filter(root, PINNED_MD_SURVIVORS)
    errors += check_libpaths(root, PINNED_LIBPATHS_ORDER)
    if errors:
        print("check-ci-cache-and-filter failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("check-ci-cache-and-filter: .gitlab-ci.yml matches the pinned expectations.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
