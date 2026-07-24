# Backend parity (PSLR-gnmvyymh).
#
# The in-tree fallback and the optional libidn2 label backend must make
# IDENTICAL accept/reject decisions and produce IDENTICAL canonical output.
# Error *messages* are deliberately NOT part of the contract: the two backends
# word rejections differently (e.g. for "xn--zzz999.com" the fallback reports
# "Truncated punycode input" while libidn2 reports "string contains invalid
# punycode data"). Parity is therefore asserted on the DECISION (accept vs
# reject) and on the OUTPUT of accepted inputs -- never on raw error text.
#
# .compare_backends() runs both backends and marks a rejection by prefixing the
# cell with "__ERROR__: ". The fallback column is always populated; the libidn2
# column is NA when libidn2 is absent (Windows ships fallback-only).

iserr <- function(v) !is.na(v) & startsWith(v, "__ERROR__")

# Decompose a .compare_backends() result into per-backend (rejected?, output),
# where output is NA on rejection so accepted-output parity ignores error text.
backend_decisions <- function(input, mode, strict = TRUE) {
  r <- punycoder:::.compare_backends(input, mode, strict)
  list(
    available = r$available,
    fb_reject = iserr(r$fallback),
    li_reject = iserr(r$libidn2),
    fb_out = ifelse(iserr(r$fallback), NA_character_, r$fallback),
    li_out = ifelse(iserr(r$libidn2), NA_character_, r$libidn2)
  )
}

# Assert fallback and libidn2 agree on accept/reject AND on canonical output.
# Skips when libidn2 is unavailable (e.g. Windows); the unconditional fallback
# tests below keep the file meaningful in that case.
expect_backend_parity <- function(input, mode, strict = TRUE) {
  d <- backend_decisions(input, mode, strict)
  skip_if(!d$available, "libidn2 backend is not available")
  expect_identical(d$fb_reject, d$li_reject) # identical accept/reject decision
  expect_identical(d$fb_out, d$li_out) # identical canonical output (accepted)
  invisible(d)
}

# --- Corpora --------------------------------------------------------------

# Valid IDN domains: multiple scripts, multi-label PSL-shaped names, an already
# canonical A-label (idempotence), non-transitional sharp-s, and a single root
# dot. Both backends must accept all of these.
parity_accept_domains <- c(
  "bücher.example.co.uk",
  "münchen.de",
  "例え.テスト",
  "δοκιμή.com", # δοκιμή.com (Greek)
  "xn--mnchen-3ya.de",
  "faß.de", # faß.de (non-transitional)
  "example.com.",
  "a.b.c.d.example"
)

# Canonical A-labels for the decode direction.
parity_accept_ace <- c(
  "xn--bcher-kva.example.co.uk",
  "xn--mnchen-3ya.de",
  "xn--r8jz45g.xn--zckzah",
  "xn--jxalpdlp.com",
  "example.com."
)

# U-label hosts that survive a decode(encode(.)) round trip unchanged. Excludes
# the already-A-label case (it decodes to its U-label and would not equal the
# input).
roundtrip_domains <- c(
  "bücher.example.co.uk",
  "münchen.de",
  "例え.テスト",
  "δοκιμή.com",
  "faß.de",
  "example.com.",
  "a.b.c.d.example"
)

# Inputs both backends must reject, spanning the validation pipeline: empty
# name, STD3-illegal char, empty label, leading dot, hyphen placement,
# whitespace, and malformed ACE payload. DNS length validation is covered by
# validate_domain()/URL host tests, not the raw punycode codec.
parity_reject_domains <- c(
  "",
  "a_b.com",
  "a..b.com",
  ".com",
  "-bad-.com",
  "exa mple.com",
  "xn--zzz999.com"
)

# --- Backend metadata -----------------------------------------------------

test_that("backend info exposes availability and selected backend", {
  info <- punycoder:::.backend_info()

  expect_named(info, c("automatic", "has_libidn2"))
  expect_type(info$automatic, "character")
  expect_type(info$has_libidn2, "logical")
  expect_length(info$has_libidn2, 1)
})

test_that("backend comparison propagates NA inputs as NA", {
  result <- punycoder:::.compare_backends(
    c("example.com", NA_character_), "encode_domain"
  )

  expect_false(is.na(result$fallback[[1]]))
  expect_true(is.na(result$fallback[[2]]))
  if (isTRUE(result$available)) {
    expect_true(is.na(result$libidn2[[2]]))
  }
})

test_that("backend comparison transcodes Latin-1 input to UTF-8", {
  latin1 <- latin1_bytes(0x63, 0x61, 0x66, 0xE9, 0x2E, 0x63, 0x6F, 0x6D)
  result <- punycoder:::.compare_backends(latin1, "encode_domain")

  expect_identical(result$fallback, "xn--caf-dma.com")
  if (isTRUE(result$available)) {
    expect_identical(result$libidn2, "xn--caf-dma.com")
  }
})

test_that("backend comparison reports unsupported modes as errors", {
  result <- punycoder:::.compare_backends("example.com", "bogus_mode")

  expect_true(startsWith(result$fallback[[1]], "__ERROR__: "))
  expect_match(result$fallback[[1]], "Unknown backend comparison mode")
  if (isTRUE(result$available)) {
    expect_true(startsWith(result$libidn2[[1]], "__ERROR__: "))
    expect_match(result$libidn2[[1]], "Unknown backend comparison mode")
  } else {
    expect_true(is.na(result$libidn2[[1]]))
  }
})

# --- Cross-backend parity (requires libidn2) ------------------------------

test_that("fallback and libidn2 agree on RFC 3492 vectors", {
  vectors <- read.csv(
    system.file("testdata", "rfc3492_vectors.csv", package = "punycoder"),
    stringsAsFactors = FALSE
  )

  # RFC vectors include generic strings, not only DNS-valid labels. The raw
  # codec's strict mode keeps structural checks without DNS length caps.
  expect_backend_parity(vectors$unicode, "encode_domain", strict = TRUE)
  expect_backend_parity(vectors$ascii, "decode_domain", strict = TRUE)
})

test_that("fallback and libidn2 agree on multi-script PSL-shaped domains", {
  expect_backend_parity(parity_accept_domains, "encode_domain")
  expect_backend_parity(parity_accept_ace, "decode_domain")
})

test_that("fallback and libidn2 agree to reject malformed domains", {
  # Both must reject every input; error *messages* may differ (e.g. the bad ACE
  # payload), which is exactly why parity is asserted on the decision, not text.
  d <- backend_decisions(parity_reject_domains, "encode_domain")
  skip_if(!d$available, "libidn2 backend is not available")
  expect_identical(d$fb_reject, d$li_reject)
  expect_true(all(d$fb_reject))
})

# --- Fallback correctness without libidn2 ---------------------------------
#
# When libidn2 is present the public API routes label work through it, so the
# fallback is otherwise exercised only here. These run on every platform and
# pin fallback behavior even when the cross-backend tests above skip.

test_that("fallback backend rejects malformed domains on its own", {
  d <- backend_decisions(parity_reject_domains, "encode_domain")
  expect_true(all(d$fb_reject))
})

test_that("fallback backend round-trips valid IDN domains on its own", {
  enc <- backend_decisions(roundtrip_domains, "encode_domain")$fb_out
  expect_false(anyNA(enc)) # all accepted

  dec <- backend_decisions(enc, "decode_domain")$fb_out
  expect_identical(dec, roundtrip_domains)
})
