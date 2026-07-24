test_that("is_punycode correctly identifies punycode domains", {
  # Should identify punycode domains
  expect_true(is_punycode("xn--example"))
  expect_true(is_punycode("xn--caf-dma.com"))
  expect_true(is_punycode("subdomain.xn--example.com"))

  # Should not identify regular domains as punycode
  expect_false(is_punycode("example.com"))
  expect_false(is_punycode("test.org"))
  expect_false(is_punycode("subdomain.example.net"))
})

test_that("is_punycode handles vectorized input", {
  domains <- c("xn--example", "regular.com", "xn--test", "normal.org")
  result <- is_punycode(domains)

  expect_length(result, 4)
  expect_identical(result, c(TRUE, FALSE, TRUE, FALSE))
})

test_that("is_punycode validates input", {
  expect_rejects_non_character(is_punycode)
})

test_that("is_idn correctly identifies internationalized domains", {
  # ASCII domains should not be considered IDN
  expect_false(is_idn("example.com"))
  expect_false(is_idn("test.org"))
  expect_false(is_idn("subdomain.example.net"))

  expect_true(is_idn("café.com"))
  expect_true(is_idn("москва.рф"))
})

test_that("is_idn handles vectorized input", {
  domains <- c("example.com", "test.org", "another.net")
  result <- is_idn(domains)

  expect_length(result, 3)
  expect_type(result, "logical")
})

test_that("is_idn validates input", {
  expect_rejects_non_character(is_idn)
})

test_that("validate_domain returns proper structure", {
  result <- validate_domain("example.com")

  expect_type(result, "list")
  expect_s3_class(result, "punycoder_validation")
  expect_named(result, c("domains", "valid", "errors", "error_codes"))
})

test_that("validate_domain handles valid domains", {
  valid_domains <- c("example.com", "test.org", "subdomain.example.net")
  result <- validate_domain(valid_domains)

  expect_length(result$domains, 3)
  expect_length(result$valid, 3)
  expect_length(result$errors, 3)

  # All should be valid for basic ASCII domains
  expect_true(all(result$valid))
})

test_that("validate_domain handles invalid domains", {
  result <- validate_domain(NA_character_)

  expect_false(result$valid[1])
  expect_length(result$errors[[1]], 1)
  expect_identical(result$errors[[1]][1], "Domain is NA")
  expect_identical(result$error_codes[[1]], "domain_na")

  invalid <- validate_domain("invalid..domain")
  expect_false(invalid$valid[1])
  expect_true(any(
    grepl("empty label", invalid$errors[[1]], fixed = TRUE)
  ))
  expect_identical(invalid$error_codes[[1]], "domain_empty_label")
})

test_that("validate_domain exposes machine-readable error codes", {
  result <- validate_domain(c(
    "example.com",
    "-bad.com",
    "bad_label.com",
    "xn--z.com"
  ))

  expect_true(result$valid[1])
  expect_identical(result$errors[[1]], character())
  expect_identical(result$error_codes[[1]], character())

  expect_identical(result$error_codes[[2]], "domain_label_hyphen")
  expect_identical(result$error_codes[[3]], "ascii_domain_characters")
  expect_identical(result$error_codes[[4]], "truncated_punycode_input")
  expect_true(all(lengths(result$errors[-1]) == 1L))
})

test_that("validate_domain strict parameter works", {
  expect_no_error(validate_domain("example.com", strict = TRUE))
  expect_no_error(validate_domain("example.com", strict = FALSE))
})

test_that("validate_domain validates input", {
  expect_rejects_non_character(validate_domain)
})

test_that("print method for validation results works", {
  result <- validate_domain(c("example.com", NA_character_))

  # Capture output to verify it contains expected elements. The assignment also
  # verifies that printing does not error.
  output <- capture.output(returned <- print(result))
  expect_identical(returned, result)
  expect_true(any(grepl(
    "Punycoder Domain Validation Results", output, fixed = TRUE
  )))
  expect_true(any(grepl("example.com", output, fixed = TRUE)))
  expect_true(any(grepl("Domain is NA", output, fixed = TRUE)))
  expect_true(any(grepl("Valid:  TRUE", output, fixed = TRUE)))
  expect_true(any(grepl("Valid:  FALSE", output, fixed = TRUE)))
})

test_that("print method shows a count header and error codes", {
  result <- validate_domain(c("example.com", "-bad.com"))
  output <- capture.output(print(result))

  expect_true(any(grepl(
    "2 domains: 1 valid, 1 invalid (strict = TRUE)", output, fixed = TRUE
  )))
  expect_true(any(grepl("[domain_label_hyphen]", output, fixed = TRUE)))
})

test_that("print method truncates above 10 elements", {
  domains <- sprintf("example%d.com", seq_len(12))
  output <- capture.output(print(validate_domain(domains)))

  expect_true(any(grepl(
    "... and 2 more. Use summary() for counts by error code.",
    output,
    fixed = TRUE
  )))
  expect_true(any(grepl("Domain: example10.com", output, fixed = TRUE)))
  expect_false(any(grepl("Domain: example11.com", output, fixed = TRUE)))
})

test_that("print method does not truncate at exactly 10 elements", {
  domains <- sprintf("example%d.com", seq_len(10))
  output <- capture.output(print(validate_domain(domains)))

  expect_false(any(grepl("more. Use summary()", output, fixed = TRUE)))
  expect_true(any(grepl(
    "10 domains: 10 valid, 0 invalid", output, fixed = TRUE
  )))
  expect_true(any(grepl("Domain: example10.com", output, fixed = TRUE)))
})

test_that("print method formats large counts with thousands separators", {
  n <- 1500L
  big <- structure(
    list(
      domains = sprintf("d%d.example", seq_len(n)),
      valid = rep(TRUE, n),
      errors = rep(list(character()), n),
      error_codes = rep(list(character()), n)
    ),
    class = c("punycoder_validation", "list"),
    strict = TRUE
  )
  output <- capture.output(print(big))

  expect_true(any(grepl(
    "1,500 domains: 1,500 valid, 0 invalid", output, fixed = TRUE
  )))
  expect_true(any(grepl("... and 1,490 more.", output, fixed = TRUE)))
})

test_that("summary() aggregates error codes in descending order", {
  result <- validate_domain(c(
    "example.com", "-bad.com", "-worse.com", "bad_label.com"
  ))
  aggregate <- summary(result)

  expect_s3_class(aggregate, "punycoder_validation_summary")
  expect_s3_class(aggregate, "data.frame")
  expect_named(aggregate, c("error_code", "n"))
  expect_type(aggregate$error_code, "character")
  expect_type(aggregate$n, "integer")
  expect_identical(
    aggregate$error_code,
    c("domain_label_hyphen", "ascii_domain_characters")
  )
  expect_identical(aggregate$n, c(2L, 1L))
})

test_that("summary() carries counts as attributes", {
  aggregate <- summary(validate_domain(c("example.com", "-bad.com")))

  expect_identical(attr(aggregate, "n"), 2L)
  expect_identical(attr(aggregate, "n_valid"), 1L)
  expect_identical(attr(aggregate, "n_invalid"), 1L)
  expect_true(attr(aggregate, "strict"))
  expect_false(attr(
    summary(validate_domain("example.com", strict = FALSE)), "strict"
  ))
})

test_that("summary() reports zero rows when every domain is valid", {
  aggregate <- summary(validate_domain(c("example.com", "test.org")))

  expect_identical(nrow(aggregate), 0L)
  expect_named(aggregate, c("error_code", "n"))
  expect_identical(attr(aggregate, "n_invalid"), 0L)

  output <- capture.output(returned <- print(aggregate))
  expect_identical(returned, aggregate)
  expect_true(any(grepl("No errors.", output, fixed = TRUE)))
  expect_false(any(grepl("error_code", output, fixed = TRUE)))
})

test_that("summary() prints an aggregate and stays programmable", {
  aggregate <- summary(validate_domain(c(
    "example.com", "-bad.com", "-worse.com"
  )))
  output <- capture.output(returned <- print(aggregate))

  expect_identical(returned, aggregate)
  expect_true(any(grepl(
    "Punycoder validation summary (strict = TRUE)", output, fixed = TRUE
  )))
  expect_true(any(grepl(
    "3 domains: 1 valid, 2 invalid", output, fixed = TRUE
  )))
  expect_true(any(grepl("error_code", output, fixed = TRUE)))

  # The aggregate is data, not just console output.
  expect_identical(aggregate$error_code[1], "domain_label_hyphen")
  expect_identical(attr(aggregate, "n_invalid"), 2L)
})

test_that("validation summaries include valid and invalid messages", {
  result <- validate_domain(c("example.com", "invalid..domain"))
  summary <- punycoder:::get_validation_summary(result)

  expect_identical(summary[[1]], "Valid")
  expect_true(grepl(
    "empty label", summary[[2]], fixed = TRUE
  ))
  expect_error(
    punycoder:::get_validation_summary(list(errors = list(character()))),
    "punycoder_validation"
  )
})

test_that("validation summaries collapse multiple errors", {
  result <- structure(
    list(
      domains = "example.com",
      valid = FALSE,
      errors = list(c("first problem", "second problem")),
      error_codes = list(c("first", "second"))
    ),
    class = c("punycoder_validation", "list")
  )

  expect_identical(
    punycoder:::get_validation_summary(result),
    "first problem; second problem"
  )
})

test_that("validate_domain exposes lower-level domain error messages", {
  long_unicode_label <- strrep("é", 70)
  label_over_internal_cap <- strrep("a", 1025)

  result <- validate_domain(c(
    "",
    "a..b",
    "-bad.com",
    "bad_label.com",
    long_unicode_label,
    label_over_internal_cap,
    "xn--z"
  ))

  expect_identical(result$error_codes[[1]], "domain_empty")
  expect_match(result$errors[[1]], "cannot be empty")

  expect_identical(result$error_codes[[2]], "domain_empty_label")
  expect_match(result$errors[[2]], "empty label")

  expect_identical(result$error_codes[[3]], "domain_label_hyphen")
  expect_match(result$errors[[3]], "start or end with hyphen")

  expect_identical(result$error_codes[[4]], "ascii_domain_characters")
  expect_match(result$errors[[4]], "letters, numbers and hyphens")

  expect_identical(result$error_codes[[5]], "encoded_label_too_long")
  expect_match(result$errors[[5]], "exceeds 63 characters")

  expect_identical(result$error_codes[[6]], "domain_too_long")
  expect_match(result$errors[[6]], "max 253 characters")

  expect_identical(result$error_codes[[7]], "truncated_punycode_input")
  expect_match(result$errors[[7]], "Truncated punycode input")
})

test_that("strict domain validation catches length and character constraints", {
  long_label <- strrep("a", 64)
  overlong_domain <- paste0(long_label, ".com")
  expect_identical(puny_encode(overlong_domain, strict = TRUE), overlong_domain)
  expect_false(validate_domain(overlong_domain, strict = TRUE)$valid)

  huge_domain <- paste0(strrep("a", 254), ".com")
  expect_identical(puny_encode(huge_domain, strict = TRUE), huge_domain)
  expect_false(validate_domain(huge_domain, strict = TRUE)$valid)

  expect_error(puny_encode("bad_label.com", strict = TRUE), "hyphens")
  expect_false(is.na(puny_encode("bad_label.com", strict = FALSE)))
  expect_error(puny_encode(".", strict = TRUE), "cannot be empty")
})

test_that("validate_domain surfaces backend-invariant codec error codes", {
  # validate_domain() runs the full validation pipeline and reports the stable
  # ErrorCode name per element. These inputs fail in code paths that both label
  # backends share (UTF-8 decoding in the encoder, and the domain-layer length
  # cap), so the exact code is identical whether or not libidn2 is present.
  code <- function(x, strict = TRUE) {
    validate_domain(x, strict = strict)$error_codes[[1]]
  }

  # Ill-formed UTF-8 in a would-be U-label: both backends validate UTF-8 via the
  # same utf8_to_codepoints() before handing off to the codec.
  expect_identical(code(raw_utf8(0xFF)), "invalid_utf8_sequence")
  expect_identical(code(raw_utf8(0xC3)), "truncated_utf8_sequence")
  expect_identical(code(raw_utf8(0xC3, 0x61)), "invalid_utf8_continuation")
  expect_identical(code(raw_utf8(0xC0, 0x80)), "overlong_utf8_sequence")

  # Internal label-length DoS cap is a domain-layer guard, backend-independent
  # (strict = FALSE skips the DNS-length guard that would otherwise mask it).
  expect_identical(
    code(strrep("a", 2000), strict = FALSE), "label_length_limit"
  )
})

test_that("validate_domain reports a decode error for malformed A-labels", {
  # Malformed xn-- labels are rejected by both backends, but the *specific*
  # ErrorCode is deliberately not part of the cross-backend contract: libidn2
  # and the in-tree fallback word rejections differently (see test-backends.R).
  # Assert the decision (rejected, with a code from the punycode-decode family)
  # rather than a single value that would differ on libidn2-less platforms.
  decode_error_codes <- c(
    "invalid_punycode_label", "invalid_punycode_digit", "punycode_overflow",
    "decoded_code_point_out_of_range", "invalid_utf8_code_point",
    "truncated_punycode_input"
  )
  check_rejected <- function(x, strict = TRUE) {
    res <- validate_domain(x, strict = strict)
    expect_false(res$valid[[1]])
    expect_length(res$error_codes[[1]], 1L)
    expect_true(res$error_codes[[1]] %in% decode_error_codes)
  }

  check_rejected("xn--CAF-DMA")                          # non-canonical A-label
  check_rejected(paste0("xn--", strrep("z", 40)))        # out-of-range decode
  check_rejected("xn--a*b", strict = FALSE)              # invalid digit
  check_rejected(paste0("xn--", strrep("9", 20)), strict = FALSE) # overflow
  check_rejected(paste0("xn--", strrep("z", 30)), strict = FALSE) # out of range
})

test_that("domain at 253-char boundary", {
  # 63 + 1 + 63 + 1 + 63 + 1 + 59 = 251; add 2 more to hit 253
  domain_253 <- paste0(
    strrep("a", 63), ".",
    strrep("b", 63), ".",
    strrep("c", 63), ".",
    strrep("d", 61)
  )
  stopifnot(nchar(domain_253) == 253)
  expect_no_error(puny_encode(domain_253, strict = TRUE))

  domain_254 <- paste0(
    strrep("a", 63), ".",
    strrep("b", 63), ".",
    strrep("c", 63), ".",
    strrep("d", 62)
  )
  stopifnot(nchar(domain_254) == 254)
  expect_identical(puny_encode(domain_254, strict = TRUE), domain_254)
  expect_false(validate_domain(domain_254, strict = TRUE)$valid)
})
