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
#' @param x Character vector of hostnames. `NA` elements pass through as `NA`
#'   (missing, not invalid). Names are preserved.
#' @param strict Logical scalar. `TRUE` (the default) applies the full profile.
#'   `strict = FALSE` is reserved for a future documented relaxed variant and
#'   currently behaves identically to `TRUE`. This function never reads the
#'   `punycoder.strict` option.
#' @return A character vector the same length as `x`. Each element is the
#'   canonical lowercase ASCII A-label host, or `NA_character_` when the input
#'   is `NA` or invalid under the profile.
#' @seealso [normalization_profile_info()] for the profile identity,
#'   [puny_encode()] for the lower-level RFC 3492 transform.
#' @examples
#' host_normalize(c("Example.COM", "münchen.de", "example.com."))
#' host_normalize("a_b.com") # NA: STD3 rejects "_"
#' @export
host_normalize <- function(x, strict = TRUE) {
  .assert_character(x, "x")
  .assert_flag(strict, "strict")
  out <- host_normalize_cpp(enc2utf8(x), strict)
  names(out) <- names(x)
  out
}

#' Canonical-host normalization profile identity
#'
#' Returns the stable, machine-readable identity of the normalization profile
#' applied by [host_normalize()]. Downstream packages read `profile` and
#' `unicode_version` to key reproducibility on the exact normalization
#' behavior; the `backend` column is diagnostic only and must never enter a
#' reproducibility or cache key.
#'
#' @return A one-row `data.frame` with columns `profile`, `unicode_version`,
#'   `idna`, `transitional`, `use_std3`, `check_hyphens`, `check_bidi`,
#'   `check_joiners`, and `backend`.
#' @seealso [host_normalize()].
#' @examples
#' normalization_profile_info()
#' @export
normalization_profile_info <- function() {
  data.frame(
    profile = "uts46-nontransitional-std3-v1",
    unicode_version = normalization_unicode_version_cpp(),
    idna = "uts46",
    transitional = FALSE,
    use_std3 = TRUE,
    check_hyphens = TRUE,
    check_bidi = TRUE,
    check_joiners = TRUE,
    # Normalization always uses the in-tree Punycode transform, so the
    # mapping/NFC/validation pipeline is independent of whether libidn2 is
    # present (contract section 6).
    backend = "fallback",
    stringsAsFactors = FALSE
  )
}
