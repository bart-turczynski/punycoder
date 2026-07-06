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

test_that("validate_domain surfaces every reachable codec-level error code", {
  # validate_domain() runs the full validation pipeline and reports the stable
  # ErrorCode name per element, so these inputs exercise the UTF-8,
  # punycode-decode, and length guards below the domain layer -- and with them
  # the ErrorCode -> code-name mapping. strict = FALSE is used where a strict
  # ASCII / DNS-length guard would otherwise mask the deeper codec error.
  code <- function(x, strict = TRUE) {
    validate_domain(x, strict = strict)$error_codes[[1]]
  }

  # Ill-formed UTF-8 in a would-be U-label.
  expect_identical(code(raw_utf8(0xFF)), "invalid_utf8_sequence")
  expect_identical(code(raw_utf8(0xC3)), "truncated_utf8_sequence")
  expect_identical(code(raw_utf8(0xC3, 0x61)), "invalid_utf8_continuation")
  expect_identical(code(raw_utf8(0xC0, 0x80)), "overlong_utf8_sequence")
  expect_identical(
    code(paste0("xn--", strrep("z", 40))), "invalid_utf8_code_point"
  )

  # A-label whose uppercase payload does not re-encode to itself (RFC 5891 5.4).
  expect_identical(code("xn--CAF-DMA"), "invalid_punycode_label")

  # Punycode decode failures; strict = FALSE reaches the reference decoder.
  expect_identical(code("xn--a*b", strict = FALSE), "invalid_punycode_digit")
  expect_identical(
    code(paste0("xn--", strrep("9", 20)), strict = FALSE), "punycode_overflow"
  )
  expect_identical(
    code(paste0("xn--", strrep("z", 30)), strict = FALSE),
    "decoded_code_point_out_of_range"
  )

  # Internal label-length DoS cap fires before the DNS checks (strict = FALSE
  # skips the domain-length guard that would otherwise mask it).
  expect_identical(
    code(strrep("a", 2000), strict = FALSE), "label_length_limit"
  )
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
