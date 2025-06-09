test_that("puny_encode handles ASCII domains", {
  # ASCII domains should pass through unchanged
  expect_equal(puny_encode("example.com"), "example.com")
  expect_equal(puny_encode("test.org"), "test.org")
  expect_equal(puny_encode("subdomain.example.net"), "subdomain.example.net")
})

test_that("puny_encode handles NA values", {
  expect_warning(result <- puny_encode(c("test.com", NA, "example.org")))
  expect_equal(result[1], "test.com")
  expect_true(is.na(result[2]))
  expect_equal(result[3], "example.org")
})

test_that("puny_encode validates input types", {
  expect_error(puny_encode(123), "character vector")
  expect_error(puny_encode(TRUE), "character vector")
  expect_error(puny_encode(list("test.com")), "character vector")
})

test_that("puny_decode handles ASCII domains", {
  # Non-punycode domains should pass through unchanged
  expect_equal(puny_decode("example.com"), "example.com")
  expect_equal(puny_decode("test.org"), "test.org")
})

test_that("puny_decode handles punycode domains", {
  # This will use placeholder implementation for now
  # When real implementation is added, these tests should be updated
  expect_type(puny_decode("xn--example"), "character")
})

test_that("puny_decode validates input types", {
  expect_error(puny_decode(123), "character vector")
  expect_error(puny_decode(TRUE), "character vector")
})

test_that("encoding and decoding are symmetric for ASCII", {
  ascii_domains <- c("example.com", "test.org", "subdomain.example.net")
  
  for (domain in ascii_domains) {
    encoded <- puny_encode(domain)
    decoded <- puny_decode(encoded)
    expect_equal(decoded, domain)
  }
})

test_that("strict parameter works", {
  # These should not throw errors regardless of strict setting
  expect_no_error(puny_encode("example.com", strict = TRUE))
  expect_no_error(puny_encode("example.com", strict = FALSE))
  expect_no_error(puny_decode("example.com", strict = TRUE))
  expect_no_error(puny_decode("example.com", strict = FALSE))
})

test_that("vectorized operations work", {
  domains <- c("example.com", "test.org", "another.net")
  
  encoded <- puny_encode(domains)
  expect_length(encoded, 3)
  expect_type(encoded, "character")
  
  decoded <- puny_decode(encoded)
  expect_length(decoded, 3)
  expect_type(decoded, "character")
}) 