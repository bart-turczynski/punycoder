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
  expect_equal(result, c(TRUE, FALSE, TRUE, FALSE))
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
  expect_named(result, c("domains", "valid", "errors"))
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
  expect_equal(result$errors[[1]][1], "Domain is NA")

  invalid <- validate_domain("invalid..domain")
  expect_false(invalid$valid[1])
  expect_true(any(
    grepl("empty label", invalid$errors[[1]], ignore.case = TRUE)
  ))
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

  # Should not error when printing
  expect_no_error(print(result))

  # Capture output to verify it contains expected elements
  output <- capture.output(print(result))
  expect_true(any(grepl("Punycoder Domain Validation Results", output)))
  expect_true(any(grepl("example.com", output)))
})

test_that("validation summaries include valid and invalid messages", {
  result <- validate_domain(c("example.com", "invalid..domain"))
  summary <- punycoder:::get_validation_summary(result)

  expect_equal(summary[[1]], "Valid")
  expect_true(grepl("empty label", summary[[2]], ignore.case = TRUE))
  expect_error(
    punycoder:::get_validation_summary(list(errors = list(character()))),
    "punycoder_validation"
  )
})

test_that("strict domain validation catches length and character constraints", {
  long_label <- paste(rep("a", 64), collapse = "")
  overlong_domain <- paste0(long_label, ".com")
  expect_error(puny_encode(overlong_domain, strict = TRUE), "label too long")
  expect_false(is.na(puny_encode(overlong_domain, strict = FALSE)))

  huge_domain <- paste0(paste(rep("a", 254), collapse = ""), ".com")
  expect_error(puny_encode(huge_domain, strict = TRUE), "too long")
  expect_false(is.na(puny_encode(huge_domain, strict = FALSE)))

  expect_error(puny_encode("bad_label.com", strict = TRUE), "hyphens")
  expect_false(is.na(puny_encode("bad_label.com", strict = FALSE)))
  expect_error(puny_encode(".", strict = TRUE), "cannot be empty")
})

test_that("domain at 253-char boundary", {
  # 63 + 1 + 63 + 1 + 63 + 1 + 59 = 251; add 2 more to hit 253
  domain_253 <- paste0(
    paste(rep("a", 63), collapse = ""), ".",
    paste(rep("b", 63), collapse = ""), ".",
    paste(rep("c", 63), collapse = ""), ".",
    paste(rep("d", 61), collapse = "")
  )
  stopifnot(nchar(domain_253) == 253)
  expect_no_error(puny_encode(domain_253, strict = TRUE))

  domain_254 <- paste0(
    paste(rep("a", 63), collapse = ""), ".",
    paste(rep("b", 63), collapse = ""), ".",
    paste(rep("c", 63), collapse = ""), ".",
    paste(rep("d", 62), collapse = "")
  )
  stopifnot(nchar(domain_254) == 254)
  expect_error(puny_encode(domain_254, strict = TRUE), "too long")
})
