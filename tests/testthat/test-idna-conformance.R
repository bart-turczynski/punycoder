# Conformance check for host_normalize against the official UTS #46 corpus
# IdnaTestV2.txt, Unicode 16.0.0. We compare the non-transitional ToASCII
# column toAsciiN, which matches punycoder's pinned profile
# uts46-nontransitional-std3-v1. The parser lives in helper-idna.R; this file
# is ASCII-clean and all Unicode inputs come from the fixture.
#
# punycoder honours every UTS #46 validity flag, so under the strict v1 profile
# any status code means the row is expected to be rejected as NA. The single
# documented divergence is the trailing FQDN root dot: strict VerifyDnsLength
# flags the empty root label as A4_2, but host_normalize permits it, mapping a
# name such as example.com. to itself. CONTEXTO is not enforced and the corpus
# does not test it.

test_that("host_normalize matches UTS-46 IdnaTestV2 (Unicode 16.0.0)", {
  path <- system.file("testdata", "IdnaTestV2.txt", package = "punycoder")
  skip_if(!nzchar(path), "IdnaTestV2.txt fixture not installed")

  df <- idna_load_v2(path)
  # Guard against a silent parse failure masquerading as a pass.
  expect_gt(nrow(df), 6000L)

  # Strict v1: any status code means the row is expected to be rejected (NA).
  err <- vapply(df$status, .idna_has_codes, logical(1))
  expected <- ifelse(err, NA_character_, df$to_ascii)
  got <- host_normalize(df$source)

  both_na <- is.na(expected) & is.na(got)
  both_val <- !is.na(expected) & !is.na(got) & expected == got
  conformant <- both_na | both_val
  dev <- which(!conformant)

  # We must never reject an input UTS-46 accepts (no false rejections).
  rejects_valid <- !is.na(expected) & is.na(got)
  expect_false(any(rejects_valid))

  # Every divergence must be a trailing-dot input whose only status is A4_2
  # (empty root label) -- i.e. nothing else regressed.
  ends_in_dot <- grepl("\\.$", df$source[dev])
  only_a4_2 <- trimws(df$status[dev]) == "[A4_2]"
  expect_true(all(ends_in_dot))
  expect_true(all(only_a4_2))

  # On those rows we accept and return the ASCII form with the trailing dot.
  expect_equal(got[dev], df$to_ascii[dev])

  # Pin the deviation count to the vendored fixture so a regression in root-dot
  # or length handling shifts it and trips here.
  expect_identical(length(dev), 57L)
})
