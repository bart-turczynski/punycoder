# Canonical-host normalization contract fixtures.
# Seeds: dev/normalization-contract.md section 5. Source uses \u escapes so
# the file stays ASCII-clean for CRAN.

test_that("contract section 5 worked examples normalize as specified", {
  expect_identical(host_normalize("Example.COM"), "example.com")
  expect_identical(host_normalize("example.com."), "example.com.")
  # The umlaut host muenchen.de (with u-umlaut) maps to its A-label.
  expect_identical(host_normalize("m\u00fcnchen.de"), "xn--mnchen-3ya.de")
  expect_identical(host_normalize("xn--mnchen-3ya.de"), "xn--mnchen-3ya.de")
  # ACE prefix case is folded by UTS-46 mapping.
  expect_identical(host_normalize("XN--MNCHEN-3YA.de"), "xn--mnchen-3ya.de")
  # STD3 rejects "_".
  expect_identical(host_normalize("a_b.com"), NA_character_)
  # Leading dot -> empty label.
  expect_identical(host_normalize(".com"), NA_character_)
  # Consecutive dots -> empty label.
  expect_identical(host_normalize("a..b"), NA_character_)
  # IP literal is not rejected here; that is the caller's policy.
  expect_identical(host_normalize("1.2.3.4"), "1.2.3.4")
  expect_identical(host_normalize(""), NA_character_)
  expect_identical(host_normalize(NA_character_), NA_character_)
})

test_that("canonical fass.de keeps the sharp s (non-transitional)", {
  # Contract section 5 correction: non-transitional UTS-46 keeps U+00DF, so the
  # canonical output is the A-label xn--fa-hia.de (NOT the transitional
  # fass.de). This is the load-bearing transitional/non-transitional fixture.
  expect_identical(host_normalize("fa\u00df.de"), "xn--fa-hia.de")
  expect_identical(host_normalize("xn--fa-hia.de"), "xn--fa-hia.de")
})

test_that("a non-canonical A-label payload is rejected", {
  # An xn-- payload whose decoded U-label does not round-trip to the same
  # canonical A-label is rejected.
  expect_identical(host_normalize("xn--abc.com"), NA_character_)
})

test_that("mixed-case A-label payload normalizes via UTS-46 mapping", {
  # dev/normalization-contract.md section 5 lists "xn--MNCHEN-3ya.de" -> NA as
  # a "non-canonical A-label payload" row. That row is inconsistent with the
  # adjacent "XN--MNCHEN-3YA.de" -> valid row: UTS-46 mapping case-folds the
  # whole label before any canonical check, so both inputs map identically to
  # "xn--mnchen-3ya" and no single rule can accept one and reject the other.
  # We implement standard UTS-46 (both valid) and have flagged the contract
  # defect on PSLR-pwwtqowh; update this assertion if the contract is revised.
  expect_identical(host_normalize("xn--MNCHEN-3ya.de"), "xn--mnchen-3ya.de")
})

test_that("CheckBidi accepts valid RTL labels and rejects rule violations", {
  # U+0634 U+0628 U+0643 U+0629 = the Arabic word "network"; .com is LTR.
  expect_identical(
    host_normalize("\u0634\u0628\u0643\u0629.com"),
    "xn--ngbc5azd.com"
  )
  # An RTL label (starts with U+0627, an AL character) must not end in an L
  # character (rule 3).
  expect_identical(host_normalize("\u0627a.com"), NA_character_)
})

test_that("CheckJoiners rejects context-free ZWNJ/ZWJ", {
  # U+200C = ZWNJ, U+200D = ZWJ. With no Virama and no joining context both
  # are invalid.
  expect_identical(host_normalize("a\u200cb.com"), NA_character_)
  expect_identical(host_normalize("a\u200db.com"), NA_character_)
})

test_that("CheckHyphens rejects leading, trailing, 3rd-4th hyphens", {
  expect_identical(host_normalize("-ab.com"), NA_character_)
  expect_identical(host_normalize("ab-.com"), NA_character_)
  expect_identical(host_normalize("ab--cd.com"), NA_character_)
})

test_that("host_normalize rejects ill-formed UTF-8 input", {
  # Step 1 of host_normalize_one rejects non-UTF-8 input up front, surfacing the
  # contract's NA-on-invalid signal rather than throwing.
  expect_identical(host_normalize(raw_utf8(0xFF)), NA_character_)
  expect_identical(host_normalize(raw_utf8(0xC0, 0x80)), NA_character_)
})

test_that("terminal-dot handling matches the contract", {
  expect_identical(host_normalize("."), NA_character_)
  expect_identical(host_normalize("example.com.."), NA_character_)
})

test_that("host_normalize is vectorized and preserves names", {
  x <- c(a = "Example.COM", b = NA, c = "a_b.com")
  out <- host_normalize(x)
  expect_identical(
    out,
    c(a = "example.com", b = NA_character_, c = NA_character_)
  )
  expect_named(out, c("a", "b", "c"))
  expect_length(host_normalize(character(0)), 0L)
})

test_that("host_normalize validates its arguments", {
  expect_error(host_normalize(1L), "must be a character vector")
  expect_error(host_normalize("x", check_hyphens = NA), "check_hyphens must be")
  expect_error(
    host_normalize("x", use_std3 = c(TRUE, FALSE)), "use_std3 must be"
  )
  expect_error(
    host_normalize("x", verify_dns_length = 1L), "verify_dns_length must be"
  )
})

test_that("host_normalize relaxes exactly the named UTS #46 flag", {
  # use_std3: "_" is STD3-disallowed-but-valid; default rejects, flag admits it.
  expect_identical(host_normalize("a_b.com"), NA_character_)
  expect_identical(host_normalize("a_b.com", use_std3 = FALSE), "a_b.com")

  # check_hyphens: leading/trailing hyphen and "--" in 3rd/4th positions.
  expect_identical(host_normalize("-lead.com"), NA_character_)
  expect_identical(
    host_normalize("-lead.com", check_hyphens = FALSE), "-lead.com"
  )
  expect_identical(host_normalize("trail-.com"), NA_character_)
  expect_identical(
    host_normalize("ab--cd.com", check_hyphens = FALSE), "ab--cd.com"
  )

  # verify_dns_length: a label over 63 octets, host within other limits.
  long_label <- strrep("a", 64L)
  long_host <- paste0(long_label, ".com")
  expect_identical(host_normalize(long_host), NA_character_)
  expect_identical(
    host_normalize(long_host, verify_dns_length = FALSE), long_host
  )

  # Each flag is independent: relaxing one does not relax the others.
  expect_identical(
    host_normalize("a_b.com", check_hyphens = FALSE), NA_character_
  )
  expect_identical(host_normalize("-lead.com", use_std3 = FALSE), NA_character_)
})

test_that("relaxing a flag never changes an already-accepted result", {
  accepted <- c("Example.COM", "münchen.de", "example.com.", "a.b.c")
  strict <- host_normalize(accepted)
  relaxed <- host_normalize(
    accepted, check_hyphens = FALSE, use_std3 = FALSE, verify_dns_length = FALSE
  )
  expect_identical(relaxed, strict)
})

test_that("normalization_profile_info reports the ratified profile identity", {
  info <- normalization_profile_info()
  expect_s3_class(info, "data.frame")
  expect_identical(nrow(info), 1L)
  expect_named(info, c(
    "profile", "unicode_version", "idna", "transitional", "use_std3",
    "check_hyphens", "check_bidi", "check_joiners", "verify_dns_length",
    "backend"
  ))
  expect_identical(info$profile, "uts46-nontransitional-std3-v1")
  expect_identical(info$unicode_version, "16.0.0")
  expect_identical(info$idna, "uts46")
  expect_false(info$transitional)
  expect_true(info$use_std3)
  expect_true(info$check_hyphens)
  expect_true(info$check_bidi)
  expect_true(info$check_joiners)
  expect_true(info$verify_dns_length)
})

test_that("normalization_profile_info reports identity for a flag set", {
  # Each knob is reflected in its own column.
  expect_false(normalization_profile_info(check_hyphens = FALSE)$check_hyphens)
  expect_false(normalization_profile_info(use_std3 = FALSE)$use_std3)
  expect_false(
    normalization_profile_info(verify_dns_length = FALSE)$verify_dns_length
  )

  # Fixed (non-knob) columns never move.
  relaxed <- normalization_profile_info(
    check_hyphens = FALSE, use_std3 = FALSE, verify_dns_length = FALSE
  )
  expect_false(relaxed$transitional)
  expect_true(relaxed$check_bidi)
  expect_true(relaxed$check_joiners)
})

test_that("profile token is byte-stable for defaults, distinct per flag set", {
  # The default call is byte-identical to the historical token, so a zero-arg
  # downstream reader (e.g. pslr) sees no change.
  expect_identical(
    normalization_profile_info()$profile, "uts46-nontransitional-std3-v1"
  )

  # Any deviation appends a deterministic, fixed-order tag.
  expect_identical(
    normalization_profile_info(check_hyphens = FALSE)$profile,
    "uts46-nontransitional-std3-v1+no-check-hyphens"
  )
  expect_identical(
    normalization_profile_info(use_std3 = FALSE)$profile,
    "uts46-nontransitional-std3-v1+no-std3"
  )
  expect_identical(
    normalization_profile_info(verify_dns_length = FALSE)$profile,
    "uts46-nontransitional-std3-v1+no-verify-dns-length"
  )
  expect_identical(
    normalization_profile_info(
      check_hyphens = FALSE, use_std3 = FALSE, verify_dns_length = FALSE
    )$profile,
    paste0(
      "uts46-nontransitional-std3-v1",
      "+no-check-hyphens+no-std3+no-verify-dns-length"
    )
  )

  # Distinct flag sets never collide on the token.
  tokens <- vapply(
    list(
      normalization_profile_info(),
      normalization_profile_info(check_hyphens = FALSE),
      normalization_profile_info(use_std3 = FALSE),
      normalization_profile_info(verify_dns_length = FALSE)
    ),
    function(info) info$profile, character(1)
  )
  expect_identical(anyDuplicated(tokens), 0L)
})

test_that("normalization_profile_info validates its flag arguments", {
  expect_error(
    normalization_profile_info(check_hyphens = NA), "check_hyphens must be"
  )
  expect_error(
    normalization_profile_info(use_std3 = c(TRUE, FALSE)), "use_std3 must be"
  )
  expect_error(
    normalization_profile_info(verify_dns_length = 1L),
    "verify_dns_length must be"
  )
})
