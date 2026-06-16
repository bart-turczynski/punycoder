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
#' The profile is fixed at one pinned Unicode version per release; see
#' [normalization_profile_info()] for the machine-readable identity.
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
#' @return A character vector the same length as `x`. Each element is the
#'   canonical lowercase ASCII A-label host, or `NA_character_` when the input
#'   is `NA` or invalid under the profile.
#' @seealso [normalization_profile_info()] for the profile identity,
#'   [puny_encode()] for the lower-level RFC 3492 transform.
#' @examples
#' host_normalize(c("Example.COM", "münchen.de", "example.com."))
#' host_normalize("a_b.com") # NA: STD3 rejects "_"
#' host_normalize("a_b.com", use_std3 = FALSE) # "a_b.com"
#' @export
host_normalize <- function(x, check_hyphens = TRUE, use_std3 = TRUE,
                           verify_dns_length = TRUE) {
  .assert_character(x, "x")
  .assert_flag(check_hyphens, "check_hyphens")
  .assert_flag(use_std3, "use_std3")
  .assert_flag(verify_dns_length, "verify_dns_length")
  out <- host_normalize_cpp(enc2utf8(x), check_hyphens, use_std3,
                            verify_dns_length)
  names(out) <- names(x)
  out
}

# Derive the coarse `profile` cache token from a flag set. The default profile
# (all checks on) yields the byte-stable historical token; any deviation appends
# a deterministic, fixed-order tag so a token minted under one flag set can never
# `identical()`-match one minted under another. The token is a COARSE cache key
# only: the precise identity lives in the per-parameter columns, which downstream
# keys on (PUNY-nblrvplp). check_bidi / check_joiners / transitional are not
# knobs (fixed by the profile), so they never enter the token.
.normalization_profile_token <- function(check_hyphens, use_std3,
                                         verify_dns_length) {
  base <- "uts46-nontransitional-std3-v1"
  deviations <- c(
    if (!check_hyphens) "no-check-hyphens",
    if (!use_std3) "no-std3",
    if (!verify_dns_length) "no-verify-dns-length"
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
#' @return A one-row `data.frame` with columns `profile`, `unicode_version`,
#'   `idna`, `transitional`, `use_std3`, `check_hyphens`, `check_bidi`,
#'   `check_joiners`, `verify_dns_length`, and `backend`.
#' @seealso [host_normalize()].
#' @examples
#' normalization_profile_info()
#' normalization_profile_info(use_std3 = FALSE)
#' @export
normalization_profile_info <- function(check_hyphens = TRUE, use_std3 = TRUE,
                                       verify_dns_length = TRUE) {
  .assert_flag(check_hyphens, "check_hyphens")
  .assert_flag(use_std3, "use_std3")
  .assert_flag(verify_dns_length, "verify_dns_length")
  data.frame(
    profile = .normalization_profile_token(
      check_hyphens, use_std3, verify_dns_length
    ),
    unicode_version = normalization_unicode_version_cpp(),
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
