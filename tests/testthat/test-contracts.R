test_that("parse_url preserves object attributes and empty-path contract", {
  parsed <- parse_url("https://example.com", encode_domains = TRUE)

  expect_s3_class(parsed, "punycoder_parsed_url")
  expect_identical(attr(parsed, "encode_domains"), TRUE)
  expect_identical(parsed$path[[1]], "")
  expect_identical(parsed$domain[[1]], "example.com")
})

test_that("parse_url invalid inputs return missing components", {
  parsed <- parse_url("")

  expect_true(is.na(parsed$scheme[[1]]))
  expect_true(is.na(parsed$domain[[1]]))
  expect_true(is.na(parsed$port[[1]]))
  expect_true(is.na(parsed$path[[1]]))
  expect_true(is.na(parsed$query[[1]]))
  expect_true(is.na(parsed$fragment[[1]]))
})

test_that("validate_domain preserves result attributes", {
  result <- validate_domain("example.com", strict = FALSE)

  expect_s3_class(result, "punycoder_validation")
  expect_identical(attr(result, "strict"), FALSE)
  expect_named(result, c("domains", "valid", "errors"))
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
  expect_error(
    url_encode("", strict = TRUE),
    "^Error encoding URL:"
  )
  expect_error(
    url_decode("", strict = TRUE),
    "^Error decoding URL:"
  )
})
