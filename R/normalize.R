#' Normalize hosts to canonical comparison form
#'
#' Converts DNS hostnames to their canonical comparison form following the
#' ratified canonical-host normalization contract: Unicode NFC, case mapping,
#' UTS-46 label mapping and validation (non-transitional, with
#' `UseSTD3ASCIIRules`, `CheckHyphens`, `CheckBidi`, and `CheckJoiners`),
#' conversion to lowercase ASCII A-labels, and DNS length verification, while
#' preserving whether the input carried a single terminal root dot.
#'
#' Unlike [puny_encode()], invalid input is reported by returning
#' `NA_character_` (never by aborting), so a caller can layer its own policy.
#' See [normalization_profile_info()] for the machine-readable identity of the
#' profile a given call applies.
#'
#' A build ships one or more Unicode table sets and pins one of them as the
#' default; `unicode_version` selects among them and [unicode_versions()] lists
#' what is available. Naming a version the build does not ship is an error, not
#' a fall back to the default — a silent fallback would let a caller record a
#' profile identity describing a normalization that never ran. The Unicode
#' version is a parameter of UTS #46 conformance (all three conformance clauses
#' are phrased *"Given a version of Unicode..."*), so selecting one stays
#' conformant.
#'
#' This is a **UTS #46 profile, not IDNA2008 / RFC 5891 conformance.** UTS #46
#' is compatibility processing and deliberately differs from IDNA2008 — it
#' accepts labels IDNA2008 would reject (e.g. a label whose first character is
#' the symbol U+2615 HOT BEVERAGE becomes `"xn--53h.example"`). The pipeline
#' draws on RFC 3492 (the Punycode
#' transform), NFC per UAX #15, the RFC 5892 ContextJ rules via `CheckJoiners`
#' (ZWJ/ZWNJ only — full RFC 5892 CONTEXTO is **not** checked), the RFC 5893
#' Bidi rule via `CheckBidi`, and STD 3 (RFC 952 + RFC 1123) host-name rules via
#' `UseSTD3ASCIIRules`. IDNA2003 / Nameprep (RFC 3490/3491/3454) is not used.
#'
#' The default applies the full strict UTS #46 profile
#' (`uts46-nontransitional-std3-v1`). The `check_hyphens`, `use_std3`, and
#' `verify_dns_length` arguments are UTS #46 processing flags that can each be
#' relaxed independently; pass the *same* values to
#' [normalization_profile_info()] to obtain the identity of the resulting
#' profile. These are standard UTS #46 parameters, **not** a browser mode:
#' `CheckBidi` and `CheckJoiners` always apply and are never knobs, and full
#' WHATWG host policy (where `beStrict = false` flips exactly these three) lives
#' upstack in `rurl`, not here.
#'
#' @param x Character vector of hostnames. `NA` elements pass through as `NA`
#'   (missing, not invalid). Names are preserved.
#' @param check_hyphens Logical scalar. When `TRUE` (the default) the UTS #46
#'   `CheckHyphens` rule rejects `"--"` in the 3rd/4th positions and leading or
#'   trailing hyphens. `FALSE` drops that check.
#' @param use_std3 Logical scalar. When `TRUE` (the default) `UseSTD3ASCIIRules`
#'   restricts ASCII to letters, digits, and hyphen. `FALSE` admits other ASCII
#'   (e.g. `"_"`) that the pinned table marks STD3-disallowed-but-valid.
#' @param verify_dns_length Logical scalar. When `TRUE` (the default) each
#'   A-label must be 1-63 octets and the whole host <= 253. `FALSE` drops the
#'   length limits (empty labels are still rejected as structural errors).
#' @param unicode_version Character scalar naming a Unicode table set this build
#'   ships, or `NULL` (the default) for the pinned one. See
#'   [unicode_versions()]. An unshipped version is an error.
#' @return A character vector the same length as `x`. Each element is the
#'   canonical lowercase ASCII A-label host, or `NA_character_` when the input
#'   is `NA` or invalid under the profile.
#' @seealso [normalization_profile_info()] for the profile identity,
#'   [unicode_versions()] for the table sets available,
#'   [puny_encode()] for the lower-level RFC 3492 transform.
#' @examples
#' host_normalize(c("Example.COM", "münchen.de", "example.com."))
#' host_normalize("a_b.com") # NA: STD3 rejects "_"
#' host_normalize("a_b.com", use_std3 = FALSE) # "a_b.com"
#' host_normalize("example.com", unicode_version = unicode_versions()[[1L]])
#' @export
host_normalize <- function(x, check_hyphens = TRUE, use_std3 = TRUE,
                           verify_dns_length = TRUE, unicode_version = NULL) {
  .assert_character(x, "x")
  .assert_normalize_flags(check_hyphens, use_std3, verify_dns_length)
  version <- .resolve_unicode_version(unicode_version)
  out <- host_normalize_cpp(enc2utf8(x), version, check_hyphens, use_std3,
                            verify_dns_length)
  names(out) <- names(x)
  out
}

#' Unicode table sets available in this build
#'
#' punycoder vendors its Unicode data (combining classes, decompositions, UTS
#' #46 mapping and status, `Bidi_Class`, `Joining_Type`) as generated tables
#' compiled into the package, and a build can carry more than one version at
#' once. This reports the versions it carries, in registration order.
#'
#' Which one [host_normalize()] uses by default is the *pinned* version, and it
#' is reported by `normalization_profile_info()$unicode_version` rather than
#' marked here — that column is the single source of truth downstream packages
#' key on.
#'
#' @return A character vector of Unicode version strings, e.g. `"16.0.0"`.
#' @seealso [host_normalize()] for selecting one,
#'   [normalization_profile_info()] for the pinned default and the rest of the
#'   profile identity.
#' @examples
#' unicode_versions()
#' normalization_profile_info()$unicode_version # the pinned default
#' @export
unicode_versions <- function() {
  unicode_versions_cpp()$version
}

# Derive the coarse `profile` cache token from a flag set. The default profile
# (all checks on) yields the byte-stable historical token; any deviation appends
# a deterministic, fixed-order tag so a token minted under one flag set can
# never `identical()`-match one minted under another. The token is a COARSE
# cache key only: the precise identity lives in the per-parameter columns,
# which downstream keys on (PUNY-nblrvplp). check_bidi / check_joiners /
# transitional are not knobs (fixed by the profile), so they never enter the
# token.
.normalization_profile_token <- function(check_hyphens, use_std3,
                                         verify_dns_length, unicode_version,
                                         default_version) {
  base <- "uts46-nontransitional-std3-v1"
  deviations <- c(
    if (!check_hyphens) "no-check-hyphens",
    if (!use_std3) "no-std3",
    if (!verify_dns_length) "no-verify-dns-length",
    # The Unicode version is a parameter of UTS #46 conformance, so it obeys the
    # same rule as the flags: the pinned default keeps the historical token
    # byte-for-byte, and anything else appends a tag. It is NOT a -vN revision
    # bump -- the profile (non-transitional, STD3, same flags) is unchanged and
    # the unicode_version column carries the precise value. Without the tag two
    # normalizations that genuinely differ would mint `identical()` tokens,
    # which is the one thing the token promises cannot happen.
    if (!identical(unicode_version, default_version)) {
      paste0("unicode-", unicode_version)
    }
  )
  if (length(deviations) == 0L) {
    return(base)
  }
  paste0(base, "+", paste(deviations, collapse = "+"))
}

#' Canonical-host normalization profile identity
#'
#' Returns the stable, machine-readable identity of a normalization profile.
#' Called with no arguments it reports the default (fully strict) profile
#' [host_normalize()] applies; the `check_hyphens`, `use_std3`, and
#' `verify_dns_length` arguments report the identity of a specific flag set so a
#' caller can describe the exact profile a given normalization used. Downstream
#' packages key reproducibility on the full per-parameter column set; `profile`
#' is a coarse cache token (distinct per flag set, but no longer load-bearing
#' alone) and the `backend` column is diagnostic only and must never enter a
#' reproducibility or cache key.
#'
#' `check_bidi`, `check_joiners`, and `transitional` are fixed by the profile
#' (UTS #46 non-transitional, both bidi and joiner checks always on) and are
#' reported as constant columns rather than arguments.
#'
#' @param check_hyphens,use_std3,verify_dns_length Logical scalars selecting the
#'   flag set to report. Each defaults to `TRUE` (the strict profile).
#' @param unicode_version Character scalar naming a Unicode table set this build
#'   ships, or `NULL` (the default) for the pinned one — pass the same value
#'   given to [host_normalize()]. The `unicode_version` column reports the
#'   resolved version, so calling with no arguments still reports the pin.
#' @return A one-row `data.frame` with columns `profile`, `unicode_version`,
#'   `idna`, `transitional`, `use_std3`, `check_hyphens`, `check_bidi`,
#'   `check_joiners`, `verify_dns_length`, and `backend`.
#' @seealso [host_normalize()], [unicode_versions()].
#' @examples
#' normalization_profile_info()
#' normalization_profile_info(use_std3 = FALSE)
#' @export
normalization_profile_info <- function(check_hyphens = TRUE, use_std3 = TRUE,
                                       verify_dns_length = TRUE,
                                       unicode_version = NULL) {
  .assert_normalize_flags(check_hyphens, use_std3, verify_dns_length)
  version <- .resolve_unicode_version(unicode_version)
  data.frame(
    profile = .normalization_profile_token(
      check_hyphens, use_std3, verify_dns_length, version,
      normalization_unicode_version_cpp()
    ),
    unicode_version = version,
    idna = "uts46",
    transitional = FALSE,
    use_std3 = use_std3,
    check_hyphens = check_hyphens,
    check_bidi = TRUE,
    check_joiners = TRUE,
    verify_dns_length = verify_dns_length,
    # Normalization always uses the in-tree Punycode transform, so the
    # mapping/NFC/validation pipeline is independent of whether libidn2 is
    # present (contract section 6).
    backend = "fallback",
    stringsAsFactors = FALSE
  )
}
