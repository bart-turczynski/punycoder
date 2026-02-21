test_that("puny_encode handles ASCII domains", {
  # ASCII domains should pass through unchanged
  expect_equal(puny_encode("example.com"), "example.com")
  expect_equal(puny_encode("test.org"), "test.org")
  expect_equal(puny_encode("subdomain.example.net"), "subdomain.example.net")
})

test_that("puny_encode encodes common Unicode domains", {
  expect_equal(puny_encode("café.com"), "xn--caf-dma.com")
  expect_equal(puny_encode("москва.рф"), "xn--80adxhks.xn--p1ai")
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
  expect_equal(puny_decode("xn--caf-dma.com"), "café.com")
  expect_equal(puny_decode("xn--80adxhks.xn--p1ai"), "москва.рф")
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

test_that("encoding and decoding are symmetric for Unicode domains", {
  unicode_domains <- c("café.com", "москва.рф")

  for (domain in unicode_domains) {
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

  # Non-strict mode should return NA for invalid input elements
  expect_error(puny_encode("invalid..domain", strict = TRUE))
  expect_true(is.na(puny_encode("invalid..domain", strict = FALSE)))
})

test_that("vectorized operations work", {
  domains <- c("example.com", "café.com", "москва.рф")
  
  encoded <- puny_encode(domains)
  expect_length(encoded, 3)
  expect_type(encoded, "character")
  expect_equal(encoded[2], "xn--caf-dma.com")
  
  decoded <- puny_decode(encoded)
  expect_length(decoded, 3)
  expect_type(decoded, "character")
  expect_equal(decoded, domains)
}) 
