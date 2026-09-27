# check-bugreports v1
"""BugReports / tracker-link split gate.

WHY THIS EXISTS. CRAN runs two checks over a GitLab `BugReports:` URL and
they contradict each other. `tools::check_url_db()` actually fetches the
address; GitLab moved issue reporting to a new work-items UI, so the classic
`.../-/issues` path 404s for a signed-out client (the exact client CRAN's
check uses) while `.../-/work_items` serves 200. `tools:::.check_package_CRAN_incoming()`
never fetches anything -- it is a hardcoded string test on the path
(`!grepl("/issues(/new)?/?$", z$path)`) that only accepts the `/-/issues`
form and flags anything else, `/-/work_items` included, with a "should
likely be .../issues" NOTE. No URL satisfies both.

Both complaints are NOTEs, neither blocks acceptance, and this is not
hypothetical: the first pslr 1.2.1 upload declared `/-/work_items` in
`DESCRIPTION` and was ARCHIVED at the CRAN pretest on 2026-09-12; the
resubmission with `/-/issues` was accepted (pslr commit 509c776). So the
field the incoming check string-tests keeps the CRAN-safe form, and every
file a HUMAN actually clicks through -- which the incoming check never reads
-- points at the address that is not a dead link. See SEOR-ocbtrrnl.

`man/punycoder-package.Rd`'s "Report bugs at" link is not a separate
decision: `R/punycoder-package.R` uses roxygen2's `"_PACKAGE"` sentinel,
which generates that "Useful links" section verbatim from `DESCRIPTION`'s
own `URL:`/`BugReports:` fields. It therefore MUST agree with `DESCRIPTION`,
never with the human-facing files, or `devtools::document()` was not re-run.

WHAT IT CHECKS.

1. `DESCRIPTION`'s `BugReports:` is the CRAN-incoming-safe form: it ends in
   `/-/issues`, optionally `/new`, optionally a trailing slash, and does not
   name `/-/work_items`.
2. `man/punycoder-package.Rd`'s "Report bugs at" link is IDENTICAL to
   `DESCRIPTION`'s `BugReports:` value.
3. Every HUMAN-FACING file below that names this project's tracker names
   `/-/work_items`, and none of them still carries a `/-/issues` link:
     - codemeta.json (`"issueTracker"`)
     - SECURITY.md (the confidential-issue link)
     - .bestpractices.json (the OpenSSF badge justifications)
     - vignettes/punycoder-intro.Rmd ("Report issues at")
4. README.Rmd and README.md do not name the tracker at all today (punycoder's
   README has no "report a bug" line), so they are not required to name
   `/-/work_items`; they are only forbidden to carry a `/-/issues` link, so a
   future edit that adds one cannot reintroduce the dead form.

WHAT IT DOES NOT CHECK, ON PURPOSE.

* `NEWS.md` and `cran-comments.md` are point-in-time records of what was
  actually announced or submitted (AGENTS.md: "spec and code disagree ->
  code and ADR win" is about specs, but the same reasoning applies to a
  record of a past submission). A historical bullet or paragraph that quotes
  an old `/-/issues` form, including one arguing FOR that form, is not
  drift, so both files are exempt.
* `codemeta.json`'s `"issueTracker"` is deliberately NOT compared against
  `DESCRIPTION`'s `BugReports:` for equality -- `scripts/check-citation.py`
  does not enforce that either, and after this change the two are SUPPOSED
  to differ (that is the whole point of the split).
* Nothing here touches the network. Whether a URL currently resolves is a
  fact about the rest of the world; `R CMD check --as-cran` already fetches
  declared URLs, and a network call in a pre-push gate fails on a train.

Stdlib only, so it runs in any bare Python CI image, same shape as
`scripts/check-citation.py` (which this file does not import from or
modify -- that script is owned by a separate, fleet-wide dedup decision).

    python3 scripts/check-bugreports.py              # exit 1 on drift
    python3 scripts/check-bugreports.py --self-test  # positive/negative cases
"""

from __future__ import annotations

import re
import sys
import tempfile
from pathlib import Path

ISSUES_RE = re.compile(
    r"https://gitlab\.com/[\w.-]+/[\w.-]+/-/issues(?:/new)?/?(?=[\s)\]\"'>]|$)"
)
WORK_ITEMS_RE = re.compile(r"https://gitlab\.com/[\w.-]+/[\w.-]+/-/work_items\b")

# CRAN-incoming-safe shape: DESCRIPTION's BugReports: value, in full, must
# match this (mirrors tools:::.check_package_CRAN_incoming()'s own regex).
BUGREPORTS_SAFE_RE = re.compile(r"^https://gitlab\.com/[\w.-]+/[\w.-]+/-/issues(?:/new)?/?$")

# Files a human clicks through; the incoming check never reads any of them.
# Each names the tracker today, so each must name /-/work_items.
HUMAN_FACING_FILES = (
    "codemeta.json",
    "SECURITY.md",
    ".bestpractices.json",
    "vignettes/punycoder-intro.Rmd",
)

# Human-facing files that do not name the tracker at all: they may stay
# silent, but may never carry the dead /-/issues form.
NO_ISSUES_FILES = ("README.Rmd", "README.md")

# Point-in-time records of what was actually submitted/announced -- exempt.
EXEMPT_FILES = ("NEWS.md", "cran-comments.md")


def read_dcf(path: Path) -> dict[str, str]:
    """Flat DCF fields, joining RFC-822 style continuation lines."""
    fields: dict[str, str] = {}
    key: str | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            key = None
            continue
        if line[0].isspace():
            if key is not None:
                fields[key] += " " + line.strip()
            continue
        name, sep, value = line.partition(":")
        if not sep:
            key = None
            continue
        key = name.strip()
        fields[key] = value.strip()
    return fields


def check_repo(root: Path) -> list[str]:
    """Findings for one repository; empty when the split is intact."""
    errors: list[str] = []

    description = root / "DESCRIPTION"
    if not description.exists():
        return ["DESCRIPTION is missing; nothing to check the BugReports split against"]
    desc = read_dcf(description)
    bugreports = desc.get("BugReports", "")
    if not bugreports:
        return []  # No BugReports: field is a separate question, not drift here.

    if not BUGREPORTS_SAFE_RE.match(bugreports):
        errors.append(
            f"DESCRIPTION BugReports: is '{bugreports}', which is not the "
            f"CRAN-incoming-safe /-/issues form (optionally /new, optionally "
            f"a trailing slash). tools:::.check_package_CRAN_incoming() string-"
            f"tests this field and archived the first pslr 1.2.1 upload for "
            f"declaring /-/work_items here (pslr commit 509c776)."
        )

    man_path = root / "man" / "punycoder-package.Rd"
    if man_path.exists():
        text = man_path.read_text(encoding="utf-8")
        match = re.search(r"Report bugs at \\url\{([^}]*)\}", text)
        if match is None:
            errors.append(
                "man/punycoder-package.Rd has no 'Report bugs at' link -- either "
                "BugReports: was removed from DESCRIPTION, or the man page is "
                "stale. Re-run devtools::document()."
            )
        elif match.group(1) != bugreports:
            errors.append(
                f"man/punycoder-package.Rd's 'Report bugs at' link is "
                f"'{match.group(1)}', but DESCRIPTION's BugReports: is "
                f"'{bugreports}'. This link is generated verbatim from "
                f"DESCRIPTION by roxygen2's \"_PACKAGE\" sentinel -- re-run "
                f"devtools::document(), do not hand-edit the .Rd."
            )

    for name in HUMAN_FACING_FILES:
        path = root / name
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        if ISSUES_RE.search(text):
            errors.append(
                f"{name} still links a /-/issues form, which 404s for a "
                f"signed-out client. Repoint it at /-/work_items."
            )
        if not WORK_ITEMS_RE.search(text):
            errors.append(
                f"{name} does not name the project's /-/work_items tracker "
                f"link anywhere -- expected the human-facing tracker URL."
            )

    for name in NO_ISSUES_FILES:
        path = root / name
        if not path.exists():
            continue
        if ISSUES_RE.search(path.read_text(encoding="utf-8")):
            errors.append(
                f"{name} links a /-/issues form, which 404s for a signed-out "
                f"client. Link /-/work_items instead."
            )

    return errors


# --- self-test (positive + negative coverage, executable) --------------------


def _fixture(directory: Path, bugreports: str, man_url: str | None, human: dict[str, str]) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "DESCRIPTION").write_text(
        f"Package: fixture\nVersion: 0.1.0\nBugReports: {bugreports}\n",
        encoding="utf-8",
    )
    if man_url is not None:
        man_dir = directory / "man"
        man_dir.mkdir(parents=True, exist_ok=True)
        (man_dir / "punycoder-package.Rd").write_text(
            f"\\seealso{{\nReport bugs at \\url{{{man_url}}}\n}}\n", encoding="utf-8"
        )
    for name, content in human.items():
        (directory / name).parent.mkdir(parents=True, exist_ok=True)
        (directory / name).write_text(content, encoding="utf-8")
    return directory


def self_test() -> None:
    org = "https://gitlab.com/bart-turczynski/fixture"
    issues = f"{org}/-/issues"
    work_items = f"{org}/-/work_items"

    def run(tag: str, **kwargs) -> list[str]:
        with tempfile.TemporaryDirectory() as tmp:
            return check_repo(_fixture(Path(tmp) / tag, **kwargs))

    def expect_clean(tag: str, **kwargs) -> None:
        found = run(tag, **kwargs)
        if found:
            raise SystemExit(f"self-test FAILED ({tag}): {found}")

    def expect_flagged(tag: str, needle: str, **kwargs) -> None:
        found = run(tag, **kwargs)
        if not any(needle in f for f in found):
            raise SystemExit(f"self-test FAILED ({tag}): expected {needle!r}, got {found}")

    human_target = {
        "codemeta.json": f'{{"issueTracker": "{work_items}"}}',
        "SECURITY.md": f"1. Go to <{work_items}/new>.",
        ".bestpractices.json": f'{{"report_url_justification": "Bug tracker: {work_items}"}}',
        "vignettes/punycoder-intro.Rmd": f"- Report issues at: {work_items}",
        "README.Rmd": "No tracker line in the README.",
        "README.md": "No tracker line in the README.",
    }

    # POSITIVE: the intended split -- DESCRIPTION/man on /-/issues, human-
    # facing files on /-/work_items.
    expect_clean("split-intact", bugreports=issues, man_url=issues, human=human_target)

    # NEGATIVE: DESCRIPTION regressed to /-/work_items (the pslr pretest
    # archival case) even though it satisfies the URL-form regex.
    expect_flagged(
        "description-regressed",
        "not the CRAN-incoming-safe",
        bugreports=work_items,
        man_url=work_items,
        human=human_target,
    )

    # NEGATIVE: man page not regenerated after a hypothetical DESCRIPTION edit.
    expect_flagged(
        "man-stale",
        "generated verbatim from",
        bugreports=issues,
        man_url=work_items,
        human=human_target,
    )

    # NEGATIVE: a human-facing file reverted to /-/issues (the "prove it
    # bites" case this gate exists for).
    reverted = dict(human_target)
    reverted["SECURITY.md"] = f"open a [confidential issue]({issues}/new)"
    expect_flagged("security-reverted", "still links a /-/issues form", bugreports=issues, man_url=issues, human=reverted)

    # NEGATIVE: a human-facing file never names /-/work_items at all.
    missing = dict(human_target)
    missing["vignettes/punycoder-intro.Rmd"] = "- Report issues on GitLab."
    expect_flagged(
        "vignette-missing-work-items",
        "does not name the project's /-/work_items",
        bugreports=issues,
        man_url=issues,
        human=missing,
    )

    # NEGATIVE: a README (which need not name the tracker) gains a /-/issues
    # link.
    readme = dict(human_target)
    readme["README.Rmd"] = f"Report bugs at <{issues}>."
    expect_flagged(
        "readme-gains-issues",
        "README.Rmd links a /-/issues form",
        bugreports=issues,
        man_url=issues,
        human=readme,
    )

    print("check-bugreports self-test: PASS (1 positive + 5 negative cases)")


def main() -> int:
    if "--self-test" in sys.argv[1:]:
        self_test()
        return 0

    root = Path(__file__).resolve().parent.parent
    errors = check_repo(root)
    if errors:
        print("check-bugreports failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("check-bugreports: BugReports split (DESCRIPTION vs human-facing files) is intact.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
