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

test_that("V1 (NFC) holds for U-labels and is enforced on A-label payloads", {
  # Pins the invariant that lets validate_label() skip re-normalizing labels
  # that came straight from the split: NFC runs on the whole string before the
  # split, and U+002E is a safe break, so those labels are already NFC.
  #
  # "cafe" + U+0301 COMBINING ACUTE ACCENT is not NFC; whole-string NFC
  # composes it to U+00E9 before the label is ever validated, so the decomposed
  # spelling yields the same canonical host as the precomposed one.
  expect_identical(host_normalize("cafe\u0301.com"), "xn--caf-dma.com")
  expect_identical(host_normalize("caf\u00e9.com"), "xn--caf-dma.com")

  # A Punycode payload never goes through that pass, so V1 is still the
  # operative check there. xn--cafe-yvc is the A-label of the *decomposed*
  # sequence: it decodes to a non-NFC U-label and must be rejected, while the
  # A-label of the composed form is accepted unchanged.
  expect_identical(host_normalize("xn--cafe-yvc.com"), NA_character_)
  expect_identical(host_normalize("xn--caf-dma.com"), "xn--caf-dma.com")
})

test_that("the NFC quick check does not skip input that needs normalizing", {
  # nfc() short-circuits when UAX #15 NFC_Quick_Check says the input is already
  # normalized. That is an optimization the conformance corpus cannot localize:
  # a quick check that skips too much is silently wrong only on the input that
  # needed the pipeline. One case per way it can be wrong. Escapes rather than
  # literals throughout -- the spellings would otherwise look identical.

  # NFC_QC = Maybe: U+0301 may compose with what precedes it. Folding Maybe
  # into Yes would leave "cafe" + acute uncomposed, giving a different A-label
  # from the precomposed spelling.
  expect_identical(host_normalize("cafe\u0301.com"), "xn--caf-dma.com")
  expect_identical(host_normalize("caf\u00e9.com"), "xn--caf-dma.com")

  # NFC_QC = No: U+0340 COMBINING GRAVE TONE MARK is a canonical singleton for
  # U+0300, so "a" + U+0340 must normalize to U+00E0. Skipping it would encode
  # the deprecated character instead.
  expect_identical(host_normalize("a\u0340.com"), "xn--0ca.com")
  expect_identical(host_normalize("\u00e0.com"), "xn--0ca.com")

  # Canonical ORDER, which is not a property lookup at all. U+0316 (ccc 220)
  # before U+0334 (ccc 1) is out of canonical order, and BOTH marks are
  # NFC_QC=Yes -- so the property test passes them and only the combining-class
  # comparison can catch it. Marks that are NFC_QC=Maybe cannot test this: the
  # property test bails out first and the order test is never reached.
  expect_identical(
    host_normalize("a\u0316\u0334.com"),
    host_normalize("a\u0334\u0316.com")
  )
  expect_identical(host_normalize("a\u0316\u0334.com"), "xn--a-4cb3g.com")

  # The same invariant where both marks are NFC_QC=Maybe (ccc 230 before 220),
  # which exercises reordering inside the full pipeline rather than the check.
  expect_identical(
    host_normalize("a\u0301\u0323.com"),
    host_normalize("a\u0323\u0301.com")
  )
  expect_identical(host_normalize("a\u0301\u0323.com"), "xn--lsa752l.com")

  # Input already in NFC takes the skip and must come back untouched --
  # including a combining mark that composes with nothing, and a script with no
  # combining marks at all.
  expect_identical(host_normalize("x\u0301.com"), "xn--x-xbb.com")
  expect_identical(host_normalize("\u4e2d\u6587.com"), "xn--fiq228c.com")
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
  expect_identical(info$profile, "uts46-nontransitional-std3-v2")
  # Hardcoded on purpose: the pin is profile identity, so moving it must be a
  # deliberate edit here and in dev/normalization-contract.md, never something a
  # newly compiled-in table set can do on its own (ADR-016, ADR-017).
  expect_identical(info$unicode_version, "17.0.0")
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

test_that("profile token is stable for defaults, distinct per flag set", {
  # The default call yields the bare token at the current profile revision. It
  # went -v1 -> -v2 when the pin moved to 17.0.0 (ADR-017): the bare token is
  # default-relative, so leaving it at -v1 would have let one string denote two
  # different normalizations across that release.
  expect_identical(
    normalization_profile_info()$profile, "uts46-nontransitional-std3-v2"
  )

  # Any deviation appends a deterministic, fixed-order tag.
  expect_identical(
    normalization_profile_info(check_hyphens = FALSE)$profile,
    "uts46-nontransitional-std3-v2+no-check-hyphens"
  )
  expect_identical(
    normalization_profile_info(use_std3 = FALSE)$profile,
    "uts46-nontransitional-std3-v2+no-std3"
  )
  expect_identical(
    normalization_profile_info(verify_dns_length = FALSE)$profile,
    "uts46-nontransitional-std3-v2+no-verify-dns-length"
  )
  expect_identical(
    normalization_profile_info(
      check_hyphens = FALSE, use_std3 = FALSE, verify_dns_length = FALSE
    )$profile,
    paste0(
      "uts46-nontransitional-std3-v2",
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

# --- Unicode table fast paths (PUNY-zgaqusnu) -------------------------------
# The seven table accessors in src/unicode_tables_16_0_0.cpp answer ASCII
# without a binary search: two tables that cover ASCII (UTS-46 mapping,
# Bidi_Class) via a 128-entry direct index, the rest via a bounds test against
# their own first/last listed code point. Every one of those constants and
# arrays is DERIVED in data-raw/generate_unicode_tables.R from the UCD data the
# search reads, so the fast and slow paths cannot disagree by construction.
#
# These tests exist to catch a break in that construction -- a hand-edited
# boundary, an off-by-one in the emitted index -- which would otherwise show up
# only as a wrong answer on one code point. They assert the UTS-46 spec, not a
# snapshot of the tables.

test_that("every ASCII code point maps per UTS-46 (IDNA_ASCII direct index)", {
  # Exhaustive over the direct-index array. NUL is excluded: R strings cannot
  # carry an embedded zero byte, so it is unreachable through this surface.
  cps <- 1:127
  mid <- vapply(cps, intToUtf8, character(1))
  got <- host_normalize(paste0("a", mid, "b.com"))

  # Under the strict profile ASCII is LDH-only, with A-Z case-folded by
  # mapping and U+002E splitting the label.
  lower <- tolower(mid)
  ldh <- grepl("^[a-z0-9-]$", lower)
  expected <- ifelse(ldh, paste0("a", lower, "b.com"), NA_character_)
  expected[cps == utf8ToInt(".")] <- "a.b.com"

  expect_identical(got, expected)

  # A-Z must actually be folded, not merely accepted.
  upper <- LETTERS
  expect_identical(
    host_normalize(paste0("a", upper, "b.com")),
    paste0("a", tolower(upper), "b.com")
  )
})

test_that("Bidi_Class of ASCII survives the direct index (BIDI_ASCII)", {
  # An Arabic label makes the whole domain a Bidi domain, so CheckBidi runs and
  # reads Bidi_Class for the ASCII characters of every other label too.
  # Digits are EN, letters L, hyphen ES -- the values BIDI_ASCII must carry.
  arabic <- "\u0645\u062b\u0627\u0644" # "mithal", Arabic script (Bidi AL)
  expect_false(is.na(host_normalize(paste0(arabic, ".com"))))
  # RFC 5893 rule 2 admits EN in an RTL label; rule 3 requires it to end in
  # R/AL/EN/AN, so a trailing ASCII digit is accepted.
  expect_false(is.na(host_normalize(paste0(arabic, "1.com"))))
  # Rule 5/6: an LTR label in a Bidi domain may not contain an RTL character,
  # and may not end in a hyphen (ES).
  expect_identical(
    host_normalize(paste0(arabic, ".ex-.com")), NA_character_
  )
})

test_that("code points at the derived table bounds keep their properties", {
  # U+00C0 is the first code point with a canonical decomposition (DECOMP_FIRST)
  # and U+0300 the first with a nonzero combining class (CCC_FIRST) and the
  # smallest second element of any composition pair (COMP_B_FIRST). A guard
  # that were off by one here would silently stop composing.
  expect_identical(
    host_normalize("A\u0300.com"), # A + combining grave, composes under NFC
    host_normalize("\u00c0.com")   # precomposed A-grave
  )
  expect_identical(host_normalize("\u00c0.com"), "xn--0ca.com")

  # U+0301 (ccc 230) must still reorder/compose after the guard.
  expect_identical(
    host_normalize("e\u0301.com"),
    host_normalize("\u00e9.com")
  )

  # V5 (label must not begin with a combining mark) still fires: U+0300 is the
  # first entry of the combining-mark table (MARK_FIRST).
  expect_identical(host_normalize("\u0300abc.com"), NA_character_)
})
