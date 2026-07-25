test_that("validate_domain preserves result attributes", {
  result <- validate_domain("example.com", strict = FALSE)

  expect_s3_class(result, "punycoder_validation")
  expect_false(attr(result, "strict"))
  expect_named(result, c("domains", "valid", "errors", "error_codes"))
})

test_that("strict wrappers preserve user-facing error prefixes", {
  expect_error(
    puny_encode("https://example.com", strict = TRUE),
    "^Error encoding domain:"
  )
  expect_error(
    puny_decode("https://example.com", strict = TRUE),
    "^Error decoding domain:"
  )
})

test_that("puny_* reject URL-shaped input across every guard branch", {
  # looks_like_url_input() screens each URL marker so a full URL is never
  # mistaken for a bare domain label. Every branch must reject; a plain label
  # must pass straight through.
  url_shaped <- c(
    "https://foo.com", # scheme with a hierarchical marker
    "//foo.com",       # protocol-relative form
    "a/b",             # path separator
    "a?b",             # query delimiter
    "a#b",             # fragment delimiter
    "a@b",             # userinfo delimiter
    "tel:123"          # scheme-like prefix
  )
  for (u in url_shaped) {
    expect_error(puny_encode(u, strict = TRUE), "looks like a URL")
    expect_error(puny_decode(u, strict = TRUE), "looks like a URL")
  }

  # A bare label is not URL-shaped and encodes normally (the guard's FALSE arm).
  expect_identical(puny_encode("example", strict = TRUE), "example")
  expect_identical(puny_encode("münchen", strict = TRUE), "xn--mnchen-3ya")
})

test_that("non-strict decode of a non-ACE Unicode label passes through", {
  # A non-ASCII label with no xn-- prefix has nothing to decode. In non-strict
  # mode the decoder still validates its UTF-8 (rejecting ill-formed bytes) and
  # otherwise returns it unchanged.
  expect_identical(puny_decode("café", strict = FALSE), "café")
  expect_true(is.na(puny_decode(raw_utf8(0xFF), strict = FALSE)))
})

test_that("fallback decode rejects non-LDH A-label input (PUNY-ypjwnagl)", {
  # A valid A-label is letter-digit-hyphen; literal (basic) code points that are
  # not LDH -- '(' ')' ',' '%' etc. -- must be rejected, not decoded, so the
  # in-tree fallback agrees with libidn2 rather than passing punctuation on.
  # strict mode is rejected earlier by the domain layer's LDH check; non-strict
  # reaches the fallback decoder, which now surfaces NA instead of a lenient
  # best-effort string.
  non_ldh <- c(
    "xn--(o)-ge4ax01c3t74t",  # parentheses
    "xn--6,-r4e6182wo1ra",    # comma
    "xn---%-u4o"              # percent sign
  )
  for (lab in non_ldh) {
    expect_strict_contract(puny_decode, lab, "^Error decoding domain:")
  }
})

test_that("fallback decode rejects an empty Bootstring payload (rxvwqsou)", {
  # "xn---" is the ACE prefix followed by a delimiter and an empty payload: it
  # decodes to nothing and is not a valid A-label. Echoing it back would hide a
  # failure from the caller, so non-strict returns NA and strict errors.
  expect_strict_contract(puny_decode, "xn---", "^Error decoding domain:")
})

test_that("oversized labels are bounded in both strict and non-strict mode", {
  # A crafted xn-- label far beyond the 63-octet DNS limit must not drive the
  # O(n^2) reference decoder into a quadratic-time / unbounded-allocation DoS.
  # The length cap fires regardless of the strict flag.
  oversized <- paste0("xn--", strrep("a", 5e5))

  elapsed <- system.time(
    result <- puny_decode(oversized, strict = FALSE)
  )[["elapsed"]]
  expect_true(is.na(result))
  expect_lt(elapsed, 1)

  expect_error(
    puny_decode(oversized, strict = TRUE),
    "^Error decoding domain:"
  )

  # The same bound applies to the encode path's oversized non-ASCII input.
  oversized_unicode <- paste0(strrep("é", 5e5), ".com")
  expect_true(is.na(puny_encode(oversized_unicode, strict = FALSE)))
})

test_that("predicates answer FALSE for ill-formed UTF-8 (PUNY-cewysjxi)", {
  # The predicates promise a strictly logical answer, so malformed input is
  # FALSE -- not NA (which would break `if (is_punycode(x))`), not an error.
  # This deliberately differs from host_normalize()'s NA contract: that returns
  # a *value*, where NA is a natural "absent", while a third truth value from a
  # predicate has no precedent in base R, in stringi, or in any other language's
  # IDNA library. Both predicates must agree; they previously did not, purely
  # because is_punycode() used TRE and is_idn() used PCRE.
  ill_formed <- raw_utf8(0x78, 0x6E, 0x2D, 0x2D, 0x61, 0xED, 0xA0, 0x80)
  expect_false(validUTF8(ill_formed))

  # The regression: this used to report TRUE, steering callers into puny_decode
  # for input the rest of the package refuses to process.
  expect_false(is_punycode(ill_formed))
  expect_false(is_idn(ill_formed))

  # ...and neither predicate warns any more. is_idn() used to, because PCRE saw
  # the bytes; it no longer does.
  expect_silent(is_punycode(ill_formed))
  expect_silent(is_idn(ill_formed))

  # The third row of the issue's table: bytes with no encoding mark at all. In a
  # UTF-8 locale enc2utf8() cannot repair these either, so they are FALSE too.
  unmarked <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xE9)))
  expect_false(is_punycode(unmarked))
  expect_false(is_idn(unmarked))
  expect_silent(is_idn(unmarked))
})

test_that("predicate UTF-8 gating leaves well-formed input untouched", {
  # Gating on validUTF8() must not disturb the answers that were already
  # correct, including the marked-latin1 case the predicates always handled via
  # R's transcoding, and NA/zero-length, which stay exactly as they were.
  latin1_cafe <- latin1_bytes(0x63, 0x61, 0x66, 0xE9, 0x2E, 0x63, 0x6F, 0x6D)
  expect_false(is_punycode(latin1_cafe))
  expect_true(is_idn(latin1_cafe))

  expect_identical(
    is_punycode(c("xn--caf-dma.com", "example.com", "a.xn--p1ai")),
    c(TRUE, FALSE, TRUE)
  )
  expect_identical(is_idn(c("café.com", "example.com")), c(TRUE, FALSE))

  # expect_false() rather than expect_identical(x, FALSE) per lintr, and it
  # still distinguishes FALSE from NA, which is the point of the assertion.
  expect_false(is_punycode(NA_character_))
  expect_false(is_idn(NA_character_))
  expect_identical(is_punycode(character(0)), logical(0))
  expect_identical(is_idn(character(0)), logical(0))

  # Mixed vectors: a bad element must not perturb its neighbours' answers.
  mixed <- c("xn--caf-dma.com", raw_utf8(0xED, 0xA0, 0x80), "café.com")
  expect_identical(is_punycode(mixed), c(TRUE, FALSE, FALSE))
  expect_identical(is_idn(mixed), c(FALSE, FALSE, TRUE))
})
