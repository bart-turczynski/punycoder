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
  encoded <- punycoder:::.compare_backends(latin1, "encode_domain")

  expect_identical(encoded$fallback, "xn--caf-dma.com")
  if (isTRUE(encoded$available)) {
    expect_identical(encoded$libidn2, "xn--caf-dma.com")
  }

  decoded <- punycoder:::.compare_backends(
    "xn--caf-dma.com", "decode_domain"
  )
  expect_identical(Encoding(decoded$fallback), "UTF-8")
  if (isTRUE(decoded$available)) {
    expect_identical(Encoding(decoded$libidn2), "UTF-8")
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
    stringsAsFactors = FALSE,
    encoding = "UTF-8"
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

# --- Fallback encoder output pin (PUNY-yndiwtxb) ---------------------------
#
# The fallback encoder's output is pinned on a broad corpus, so a rewrite of
# its RFC 3492 section 6.3 loop must stay byte-identical. The corpus spans
# many distinct code points, repeats, basic code points interleaved with
# non-basic ones, wide m - n jumps up to U+10FFFD, and labels up to the
# 1024-byte cap. It is built without the RNG, so the digest is stable.

encoder_corpus <- function() {
  gcd <- function(a, b) if (b == 0L) a else gcd(b, a %% b)
  # A fixed permutation: step through x by a stride coprime to its length.
  shuffle <- function(x) {
    n <- length(x)
    step <- 7919L %% n
    while (n > 1L && (step == 0L || gcd(step, n) != 1L)) {
      step <- step + 1L
    }
    x[((seq_len(n) - 1L) * step) %% n + 1L]
  }
  basic <- utf8ToInt("abcdefghijklmnopqrstuvwxyz0123456789")
  hangul <- 0xAC00 + 0:399
  cjk <- 0x4E00 + 0:399
  latin <- c(0xE0:0xF6, 0xF8:0xFF) # lowercase Latin-1 letters
  plane2 <- 0x20000 + 0:299 # CJK Extension B
  greek <- 0x3B1:0x3C9

  per_length <- function(k) {
    h <- hangul[seq_len(k)]
    # basic code points interleaved with non-basic ones
    mixed <- as.vector(rbind(
      basic[(seq_len(k) - 1L) %% length(basic) + 1L],
      shuffle(cjk[seq_len(k)])
    ))
    labels <- list(
      h, # distinct, ascending
      rev(h), # distinct, descending
      shuffle(h), # distinct, scrambled
      rep(h[[1L]], k), # one code point repeated
      rep(h[seq_len(min(k, 5L))], length.out = k), # a few, cycled
      shuffle(c(hangul[seq_len(ceiling(k / 2))], cjk[seq_len(k %/% 2)])),
      mixed[seq_len(min(length(mixed), 400L))],
      c(basic[seq_len(min(k, 36L))], greek[(seq_len(k) - 1L) %% 25L + 1L])
    )
    # wide spans: Latin-1, then the BMP, then plane 2
    if (k <= 250L) {
      labels <- c(labels, list(shuffle(c(
        latin[(seq_len(k) - 1L) %% length(latin) + 1L],
        plane2[seq_len(k %/% 2 + 1L)],
        hangul[seq_len(k %/% 3 + 1L)]
      ))))
    }
    labels
  }
  sizes <- c(1L, 2L, 3L, 7L, 36L, 37L, 100L, 255L, 340L)
  # code points at the top of the range: the largest m - n jumps
  top <- 0x10FFFD - 0:9
  labels <- c(
    unlist(lapply(sizes, per_length), recursive = FALSE),
    list(
      c(0xE0, top),
      shuffle(c(top, basic[1:10], hangul[1:10])),
      rep(0x10FFFD, 200L),
      c(0xA1, 0x10FFFD),
      # exactly 1024 bytes, the longest label the domain layer passes on
      c(basic[[1L]], shuffle(hangul[seq_len(341L)]))
    )
  )
  vapply(labels, intToUtf8, character(1))
}

md5_of <- function(x) {
  path <- tempfile()
  on.exit(unlink(path))
  writeBin(charToRaw(paste(x, collapse = "\n")), path)
  unname(tools::md5sum(path))
}

test_that("fallback encoder output is pinned on a broad corpus", {
  corpus <- encoder_corpus()
  expect_length(corpus, 84L)
  expect_identical(max(nchar(corpus, type = "bytes")), 1024L)

  enc <- backend_decisions(corpus, "encode_domain")$fb_out
  expect_false(anyNA(enc)) # all accepted

  # Recorded from the O(n x distinct) RFC 3492 loop before PUNY-yndiwtxb.
  expect_identical(md5_of(enc), "292cd42a45bf016a9e984387e7dfd612")

  dec <- backend_decisions(enc, "decode_domain")$fb_out
  expect_identical(dec, corpus)
})

test_that("fallback and libidn2 encoders agree on the broad corpus", {
  expect_backend_parity(encoder_corpus(), "encode_domain")
})
