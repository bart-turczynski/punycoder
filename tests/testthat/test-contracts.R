test_that(
  "parse_url preserves object attributes and empty-path contract",
  suppress_url_deprecation({
    parsed <- parse_url("https://example.com", encode_domains = TRUE)

    expect_s3_class(parsed, "punycoder_parsed_url")
    expect_identical(attr(parsed, "encode_domains"), TRUE)
    expect_identical(parsed$path[[1]], "")
    expect_identical(parsed$domain[[1]], "example.com")
  })
)

test_that(
  "parse_url invalid inputs return missing components",
  suppress_url_deprecation({
    parsed <- parse_url("")

    expect_true(is.na(parsed$scheme[[1]]))
    expect_true(is.na(parsed$domain[[1]]))
    expect_true(is.na(parsed$port[[1]]))
    expect_true(is.na(parsed$path[[1]]))
    expect_true(is.na(parsed$query[[1]]))
    expect_true(is.na(parsed$fragment[[1]]))
  })
)

test_that("validate_domain preserves result attributes", {
  result <- validate_domain("example.com", strict = FALSE)

  expect_s3_class(result, "punycoder_validation")
  expect_identical(attr(result, "strict"), FALSE)
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
  expect_error(
    suppress_url_deprecation(url_encode("", strict = TRUE)),
    "^Error encoding URL:"
  )
  expect_error(
    suppress_url_deprecation(url_decode("", strict = TRUE)),
    "^Error decoding URL:"
  )
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
