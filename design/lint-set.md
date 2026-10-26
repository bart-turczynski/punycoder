# The linter set

`.lintr` is intentionally aligned with the linter set `goodpractice::gp()` runs
(`goodpractice:::linters_to_lint()`), so the local and CI `lintr::lint_package()`
gate surfaces the same findings as the goodpractice report reviewers run.
Without that alignment a package passes its own lint gate and then trips a pile
of goodpractice findings later. Regenerate the list after a goodpractice
upgrade, comparing against `names(goodpractice:::linters_to_lint())`.

**Keep `.lintr` free of `#` comments.** It is parsed with `read.dcf()`, which
only learned to skip comment lines in R 4.6. On R 4.5 and older a single comment
makes `lint_package()` abort with `Invalid DCF format`, so the rationale lives
here instead. Keep it ASCII too: a non-ASCII byte in `.lintr` comes back
`bytes`-encoded on older R and makes any config error surface as a confusing
`sprintf()` failure instead of the real message.

Documented deviations from the goodpractice set — test-idiom and public-API
reasons a real package hits as it grows:

- `object_name_linter` / `object_usage_linter`: not part of the goodpractice set
  and deliberately NOT added. The cucumber DSL (`when`/`then`/`context`) and the
  testthat helpers read as undefined globals to `object_usage_linter`, and
  packages commonly expose mixed-case or dotted public parameters plus
  `._`-prefixed internal helpers that `object_name_linter` would flag.
- `expect_identical_linter`: off. Suites routinely rely on `expect_equal()`'s
  numeric tolerance (`expect_equal(nrow(x), 2)` compares integer vs double) and
  its string-encoding normalization, both of which `identical()` rejects; a
  wholesale swap means retyping literals for no behavioral gain.
- `implicit_assignment_linter`: off. Tests use the standard
  `expect_warning(res <- f(), "msg")` idiom to capture both the warning and the
  return value (`expect_warning()` returns the condition, not the value).
- `library_require_linter`: off. `tests/testthat.R` and vignette setup chunks
  legitimately call `library()`.
- `undesirable_operator_linter`: configured to keep flagging `<<-`/`->>` but
  allow `:::`, which tests use to reach internal (unexported) functions.
- `case_folding_linter`: an addition (fleet sweep SEOR-rxxuzhmc). It bans
  `tolower()`, `toupper()` and `casefold()`, which follow `LC_CTYPE`: a Turkish
  or Azeri locale maps `I` to a dotless `ı`. Map ASCII letters with `chartr()`
  over `paste(LETTERS, collapse = "")` and `paste(letters, collapse = "")`
  instead, or use `letters`/`LETTERS` directly. Tests and `data-raw/` are not
  exempt: lintr 3.4 turns a directory key in `exclusions` into a whole-file
  exclusion for every linter.
- `strings_as_factors_linter`: **on**, although goodpractice 1.2.0 dropped it
  (ropensci-review-tools/goodpractice#321) and the rest of the fleet has it off.
  It was turned on while punycoder declared R >= 3.5.0, where `data.frame()`
  still defaulted to `stringsAsFactors = TRUE`. The floor is now R >= 4.1.0,
  where it defaults to `FALSE`, so the arguments it enforces are redundant but
  harmless; the linter stays on until someone decides otherwise.
