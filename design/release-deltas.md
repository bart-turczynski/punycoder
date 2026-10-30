# CRAN release checklist

Follow the fleet checklist,
[seor `design/release-checklist.md`](https://gitlab.com/bart-turczynski/seor/-/blob/main/design/release-checklist.md).
punycoder's deltas:

- **Step 1: the calendar gates the ship date, not the code.** The next
  submission window opens about a month after the last accepted version,
  however ready the code is. Landing behavior changes on `main` early costs
  nothing: only the submission is irreversible, and merging early avoids
  rebase drift. Don't hold work back to match a release date. When a release
  is already breaking, bundle further behavior changes into it: users must
  read that release's NEWS anyway, and bundling avoids a second release where
  behavior shifts under them. While the version carries `.9000`,
  `R CMD check --as-cran` reports a standing 2-part NOTE, `Days since last
  update: N` and `Version contains large components`. It is expected, not a
  defect.
- **Step 2: check that a reverse dependency calls what changed before
  assuming a coupled release.** The CRAN reverse imports are `pslr` and
  `rurl`. The 2026-06 train was real: punycoder 1.2.0 dropped
  `host_normalize()`'s inert `strict` argument while published `pslr` called
  `host_normalize(strict = TRUE)`, so `pslr` had to be fixed on CRAN first or
  1.2.0's revdep check would have broken it. The predicate-contract change
  (PUNY-cewysjxi) looked similar and was not: neither revdep called
  `is_punycode` or `is_idn`, so no ordering constraint existed.
- **Step 4: replace the BugReports paragraph in `cran-comments.md`.** The
  current file records the 1.3.0 submission, which argued that `DESCRIPTION`
  keeps `/-/issues` on purpose. The next `cran-comments.md` replaces that
  paragraph with seor ADR 0011's rationale for `/-/work_items` and the
  expected "which should likely be" NOTE
  (https://gitlab.com/bart-turczynski/seor/-/blob/main/design/adr/0011-bugreports-names-work-items.md).
- **Step 5: the release checks must be green on the release commit.** Start
  them from **Build > Pipelines > Run pipeline** on GitLab: ref `main`,
  variable `RELEASE=1`. That web pipeline runs `t2-check-release`,
  `t2-check-oldrel`, `t2-check-devel`, `t2-floor`, `t2-sanitizers`,
  `t2-locale`, `t2-ascran`, `coverage`, `osv-audit`, `security-audit`,
  `citation-version` and `t3-manual`, without `pages`. An API pipeline
  (`glab ci run`) creates nothing. The release tag runs the same jobs plus
  `pages`, but only after the submission. `t2-sanitizers` runs
  clang-ASAN/UBSAN only.
- **Step 6: add valgrind on R-hub.** R-hub's valgrind image cannot start any
  R process on this project's arm64 runner (its GCC-built R uses an x87
  instruction Rosetta 2 does not implement; [ci.md](ci.md)'s gaps list,
  "No valgrind in CI", has the detail), so valgrind is not in CI. Run it on R-hub's x86_64 runners
  before every submission and after any substantial change under `src/`:

  ```r
  rhub::rc_submit(platforms = "valgrind")
  ```

  No email comes back: the build runs in R-hub's shared `r-hub2`
  organization on GitHub, and `rc_submit()` returns its `actions_url`. Read
  the valgrind output in the test `.Rout` files there for `ERROR SUMMARY: 0
  errors` and `definitely lost: 0 bytes`, not just a green status: valgrind
  findings do not fail `R CMD check` on their own.
- **Step 14: the concept DOI is `10.5281/zenodo.20973629`.** Its
  `<concept-recid>` in the Zenodo API query is `20973629`.
