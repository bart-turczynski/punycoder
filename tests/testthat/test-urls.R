test_that("url_encode handles simple URLs", {
  expect_equal(
    url_encode("https://example.com/path"),
    "https://example.com/path"
  )
  expect_equal(url_encode("http://test.org"), "http://test.org")
})

test_that("url_encode encodes Unicode host names", {
  expect_equal(
    url_encode("https://café.example.com/path?query=value"),
    "https://xn--caf-dma.example.com/path?query=value"
  )
  expect_equal(
    url_encode("https://παράδειγμα.ελ"),
    "https://xn--hxajbheg2az3al.xn--qxam"
  )
})

test_that("url_encode validates input", {
  expect_error(url_encode(123), "character vector")
  expect_error(url_encode(TRUE), "character vector")
})

test_that("url_encode handles NA values", {
  expect_warning(
    result <- url_encode(c("https://example.com", NA, "http://test.org"))
  )
  expect_equal(result[1], "https://example.com")
  expect_true(is.na(result[2]))
  expect_equal(result[3], "http://test.org")
})

test_that("url_decode handles simple URLs", {
  expect_equal(
    url_decode("https://example.com/path"),
    "https://example.com/path"
  )
  expect_equal(url_decode("http://test.org"), "http://test.org")
})

test_that("url_decode decodes punycode host names", {
  expect_equal(
    url_decode("https://xn--caf-dma.example.com/path"),
    "https://café.example.com/path"
  )
  expect_equal(
    url_decode("https://xn--hxajbheg2az3al.xn--qxam"),
    "https://παράδειγμα.ελ"
  )
})

test_that("url_decode validates input", {
  expect_error(url_decode(123), "character vector")
  expect_error(url_decode(TRUE), "character vector")
})

test_that("url_decode handles NA values", {
  expect_warning(
    result <- url_decode(c("https://example.com", NA, "http://test.org"))
  )
  expect_equal(result[1], "https://example.com")
  expect_true(is.na(result[2]))
  expect_equal(result[3], "http://test.org")
})

test_that("parse_url returns proper structure", {
  result <- parse_url("https://example.com/path?query=value#fragment")

  expect_type(result, "list")
  expect_s3_class(result, "punycoder_parsed_url")
  expect_named(
    result,
    c("scheme", "domain", "port", "path", "query", "fragment")
  )
  expect_equal(result$scheme[[1]], "https")
  expect_equal(result$domain[[1]], "example.com")
  expect_equal(result$path[[1]], "/path")
  expect_equal(result$query[[1]], "query=value")
  expect_equal(result$fragment[[1]], "fragment")
})

test_that("parse_url handles vectorized input", {
  urls <- c("https://example.com", "http://test.org:8080")
  result <- parse_url(urls)

  expect_type(result, "list")
  expect_s3_class(result, "punycoder_parsed_url")
  expect_equal(result$domain[[2]], "test.org")
  expect_equal(result$port[[2]], 8080L)
})

test_that("parse_url validates input", {
  expect_error(parse_url(123), "character vector")
  expect_error(parse_url(TRUE), "character vector")
})

test_that("parse_url handles NA values", {
  expect_warning(result <- parse_url(c("https://example.com", NA)))
  expect_type(result, "list")
})

test_that("URL functions return character vectors", {
  result_encode <- url_encode("https://example.com")
  expect_type(result_encode, "character")

  result_decode <- url_decode("https://example.com")
  expect_type(result_decode, "character")
})

test_that("strict parameter works for URL functions", {
  expect_no_error(url_encode("https://example.com", strict = TRUE))
  expect_no_error(url_encode("https://example.com", strict = FALSE))
  expect_no_error(url_decode("https://example.com", strict = TRUE))
  expect_no_error(url_decode("https://example.com", strict = FALSE))

  expect_error(url_encode("https://[::1/path", strict = TRUE))
  expect_true(is.na(url_encode("https://[::1/path", strict = FALSE)))
})
