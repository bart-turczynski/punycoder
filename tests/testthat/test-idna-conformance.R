# Conformance check for host_normalize against the official UTS #46 corpus
# IdnaTestV2.txt. Both tests below run once per SHIPPED Unicode version, each
# against the corpus Unicode published with that version -- pairing the 17.0.0
# engine with the 16.0.0 expectations would silently under-test both. We compare
# the non-transitional ToASCII column toAsciiN, which matches punycoder's pinned
# profile uts46-nontransitional-std3-v2. The parser and the per-version fixture
# path live in helper-idna.R; this file is ASCII-clean and all Unicode inputs
# come from the fixture.
#
# punycoder honors every UTS #46 validity flag, so under the strict v1 profile
# any status code means the row is expected to be rejected as NA. The single
# documented divergence is the trailing FQDN root dot: strict VerifyDnsLength
# flags the empty root label as A4_2, but host_normalize permits it, mapping a
# name such as example.com. to itself. CONTEXTO is not enforced and the corpus
# does not test it.

# The A4_2 root-dot deviation count, per corpus. It is a property of the
# vendored fixture (17.0.0 adds two more trailing-dot rows), not of the engine,
# so it cannot be a single number. Pinned so a regression in root-dot or length
# handling shifts it and trips here.
.idna_expected_deviations <- c("16.0.0" = 57L, "17.0.0" = 59L)

test_that("host_normalize matches UTS-46 IdnaTestV2 for each shipped version", {
  for (version in unicode_versions()) {
    path <- idna_fixture_path(version)
    skip_if(!nzchar(path),
            paste("IdnaTestV2 fixture not installed for", version))

    df <- idna_load_v2(path)
    # Guard against a silent parse failure masquerading as a pass.
    expect_gt(nrow(df), 6000L)

    # Strict v1: any status code means the row is expected to be rejected (NA).
    err <- vapply(df$status, .idna_has_codes, logical(1))
    expected <- ifelse(err, NA_character_, df$to_ascii)
    got <- host_normalize(df$source, unicode_version = version)

    both_na <- is.na(expected) & is.na(got)
    both_val <- !is.na(expected) & !is.na(got) & expected == got
    conformant <- both_na | both_val
    dev <- which(!conformant)

    # We must never reject an input UTS-46 accepts (no false rejections).
    rejects_valid <- !is.na(expected) & is.na(got)
    expect_false(any(rejects_valid), info = version)

    # Every divergence must be a trailing-dot input whose only status is A4_2
    # (empty root label) -- i.e. nothing else regressed.
    ends_in_dot <- endsWith(df$source[dev], ".")
    only_a4_2 <- trimws(df$status[dev]) == "[A4_2]"
    expect_true(all(ends_in_dot), info = version)
    expect_true(all(only_a4_2), info = version)

    # On those rows we accept and return the ASCII form with the trailing dot.
    expect_identical(got[dev], df$to_ascii[dev], info = version)

    # An unlisted version must fail loudly rather than skip its count check:
    # shipping a table set with no pinned expectation is the bug this catches.
    expect_true(version %in% names(.idna_expected_deviations), info = version)
    expect_length(dev, .idna_expected_deviations[[version]])
  }
})

# Relaxing a UTS #46 flag must (1) never change a result the strict profile
# already accepts, and (2) only ever newly-accept rows whose remaining error
# codes are the ones that flag governs -- plus A4_2, the trailing-root-dot
# divergence host_normalize already tolerates under every profile. The corpus
# toAsciiN column carries the relaxed-accept output (e.g. "(4).four" under
# [U1]), so newly-accepted rows must equal it. CheckBidi / CheckJoiners are not
# knobs and are not exercised here.
#
# One documented exception: two xn-- rows carry [V2, V4]. V4 (a U-label that
# itself re-prefixes to xn--) is not one of the three exposed flags and is the
# only V4 in the corpus -- it never occurs without V2, so the strict profile
# always rejects via V2 and host_normalize has never enforced V4 independently.
# Relaxing CheckHyphens removes the V2 reason and these two slip through. This
# is out of B's scope (parameterize existing checks, not add new criteria) and
# is pinned here, exactly as the strict test pins its A4_2 root-dot divergences.
#
# Verified against both vendored corpora: the set is the same two rows under
# 16.0.0 and 17.0.0, so it is version-invariant and is deliberately NOT keyed by
# version -- a per-version list here would imply a variation that does not
# exist.
.idna_known_divergence <- list(
  check_hyphens = c("xn--xn--a--gua.pt", "xn--xn---epa")
)

test_that("relaxing a UTS-46 flag stays bounded against IdnaTestV2", {
  for (version in unicode_versions()) {
    path <- idna_fixture_path(version)
    skip_if(!nzchar(path),
            paste("IdnaTestV2 fixture not installed for", version))

    df <- idna_load_v2(path)
    expect_gt(nrow(df), 6000L)
    strict <- host_normalize(df$source, unicode_version = version)
    code_sets <- lapply(df$status, .idna_codes)

    flags <- c("check_hyphens", "use_std3", "verify_dns_length")
    for (flag in flags) {
      # The relaxed flag and the version ride on the same options struct, so
      # both are passed by name through the same call.
      got <- do.call(
        host_normalize,
        setNames(list(df$source, FALSE, version),
                 c("x", flag, "unicode_version"))
      )
      label <- paste(flag, "under Unicode", version)

      # (1) Relaxation is monotone: every strict acceptance is preserved
      # verbatim.
      kept <- !is.na(strict)
      expect_identical(got[kept], strict[kept], info = label)

      # (2) New acceptances are bounded to this flag's codes (plus tolerated
      # A4_2) and must equal the corpus relaxed-accept output. Rows outside that
      # bound must be exactly the documented divergence set for this flag.
      tolerated <- c(.idna_flag_codes[[flag]], "A4_2")
      newly <- which(is.na(strict) & !is.na(got))
      bounded <- vapply(
        code_sets[newly],
        function(codes) length(codes) > 0L && all(codes %in% tolerated),
        logical(1)
      )
      # Explicit null default: base R's null-coalescing operator arrived in
      # 4.4.0, and the package floor is R 4.1.
      known <- .idna_known_divergence[[flag]]
      if (is.null(known)) known <- character(0)
      expect_identical(
        sort(df$source[newly[!bounded]]),
        sort(known),
        info = label
      )
      expect_identical(
        got[newly[bounded]],
        df$to_ascii[newly[bounded]],
        info = label
      )
    }
  }
})

# With VerifyDnsLength on, no accepted host may carry an empty label other than
# the single trailing root dot (ADR-010), whichever way the other two flags are
# set. Checked over every corpus row rather than a handful of seeds, because the
# empty-label rejection is what separates this path from verify_dns_length =
# FALSE, where empty labels are kept (UTS #46 section 4.2 step 4).
test_that("verify_dns_length = TRUE never emits an empty label", {
  for (version in unicode_versions()) {
    path <- idna_fixture_path(version)
    skip_if(!nzchar(path),
            paste("IdnaTestV2 fixture not installed for", version))

    df <- idna_load_v2(path)
    expect_gt(nrow(df), 6000L)
    for (hyphens in c(TRUE, FALSE)) {
      for (std3 in c(TRUE, FALSE)) {
        got <- host_normalize(df$source, check_hyphens = hyphens,
                              use_std3 = std3, verify_dns_length = TRUE,
                              unicode_version = version)
        core <- sub("\\.$", "", got[!is.na(got)])
        has_empty <- !nzchar(core) | grepl("^\\.|\\.\\.|\\.$", core)
        expect_false(
          any(has_empty),
          info = paste(version, "check_hyphens", hyphens, "use_std3", std3)
        )
      }
    }
  }
})

# The converse of the bound above: a row whose every toASCII error is one the
# relaxed flags govern must convert, to the corpus toAsciiN. For VerifyDnsLength
# alone that is every A4_1 / A4_2 row -- empty labels anywhere, the empty domain
# "", "." and over-long labels (UTS #46 section 4.2 step 4). With all three
# flags off it is checked on the rows that hold an empty label; six U1 rows
# whose xn-- payload carries non-LDH ASCII ("," or "?") are a separate
# use_std3 = FALSE gap and stay out of this test.
.idna_has_empty_label <- function(x) {
  !nzchar(x) | grepl("^\\.|\\.\\.|\\.$", x)
}

test_that("rows failing only relaxed checks convert under those flags", {
  relaxed_sets <- list(
    verify_dns_length = list(
      args = list(verify_dns_length = FALSE),
      codes = .idna_flag_codes$verify_dns_length,
      empty_only = FALSE
    ),
    all_three = list(
      args = list(check_hyphens = FALSE, use_std3 = FALSE,
                  verify_dns_length = FALSE),
      codes = unlist(.idna_flag_codes[
        c("check_hyphens", "use_std3", "verify_dns_length")
      ], use.names = FALSE),
      empty_only = TRUE
    )
  )
  for (version in unicode_versions()) {
    path <- idna_fixture_path(version)
    skip_if(!nzchar(path),
            paste("IdnaTestV2 fixture not installed for", version))

    df <- idna_load_v2(path)
    expect_gt(nrow(df), 6000L)
    code_sets <- lapply(df$status, .idna_codes)
    for (set in names(relaxed_sets)) {
      spec <- relaxed_sets[[set]]
      covered <- vapply(
        code_sets,
        function(codes) length(codes) > 0L && all(codes %in% spec$codes),
        logical(1)
      )
      if (spec$empty_only) {
        covered <- covered & .idna_has_empty_label(df$to_ascii)
      }
      got <- do.call(
        host_normalize,
        c(list(df$source[covered]), spec$args, unicode_version = version)
      )
      label <- paste(set, "under Unicode", version)
      expect_identical(got, df$to_ascii[covered], info = label)
      # Empty labels other than the root are what this change is about: make
      # sure the corpus still has them, so the check cannot pass vacuously.
      inner_empty <- !nzchar(got) | grepl("^\\.|\\.\\.", got)
      expect_gt(sum(inner_empty), 10L, label = label)
    }
  }
})

# Pins the documented UTS-46-vs-IDNA2008 stance: host_normalize is UTS #46
# compatibility processing, not IDNA2008 conformance, so it ACCEPTS symbol
# code points that IDNA2008 / libidn-backed registry checks (e.g. punycode's
# puny_tld_check) reject. EURO SIGN (U+20AC) is "valid" under UTS #46 and must
# normalize, not return NA. Keep this file ASCII-clean: euros via \u escapes.
test_that("host_normalize accepts UTS-46-valid symbols IDNA2008 rejects", {
  # euro_host spells green.no with two EURO SIGN (U+20AC) code points
  euro_host <- "gr\u20ac\u20acn.no"
  expect_identical(host_normalize(euro_host), "xn--grn-l50aa.no")

  # The same name as a raw A-label round-trips and is idempotent under
  # host_normalize (already-encoded input is a fixed point).
  expect_identical(host_normalize("xn--grn-l50aa.no"), "xn--grn-l50aa.no")
})
