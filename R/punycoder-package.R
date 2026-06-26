#' @title Unicode and Punycode Domain Name Processing
#' @description
#' Provides high-performance functions for processing internationalized
#' domain names, split across two tiers.
#'
#' @details
#' The package exposes two distinct surfaces, deliberately kept separate:
#'
#' \itemize{
#'   \item A **low-level Punycode codec** ([puny_encode()] / [puny_decode()]):
#'     the raw RFC 3492 transform with `xn--` A-label framing (RFC 5890/5891)
#'     and letter-digit-hyphen checks. It performs no Unicode normalization.
#'   \item An **IDNA/UTS-46 host-normalization surface** ([host_normalize()]):
#'     Unicode NFC, UTS #46 mapping and validation, and conversion to a
#'     canonical lowercase ASCII comparison form under a pinned profile.
#' }
#'
#' Use the codec when you need the literal ASCII-Compatible Encoding of a
#' label; use [host_normalize()] when you need a standards-profiled
#' comparison form for a host name.
#'
#' @name punycoder-package
#' @useDynLib punycoder, .registration = TRUE
#' @importFrom Rcpp evalCpp
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
