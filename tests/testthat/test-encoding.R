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
  expect_rejects_non_character(puny_encode)
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
  expect_rejects_non_character(puny_decode)
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

test_that("puny domain helpers reject full URLs", {
  unicode_url <- "https://παράδειγμα.ελ"
  ascii_url <- "https://xn--hxajbheg2az3al.xn--qxam"

  expect_error(
    puny_encode(unicode_url, strict = TRUE),
    "letters, numbers and hyphens"
  )
  expect_error(
    puny_decode(unicode_url, strict = TRUE),
    "letters, numbers and hyphens"
  )
  expect_error(
    puny_decode(ascii_url, strict = TRUE),
    "letters, numbers and hyphens"
  )

  expect_true(is.na(puny_encode(unicode_url, strict = FALSE)))
  expect_true(is.na(puny_decode(unicode_url, strict = FALSE)))
  expect_true(is.na(puny_decode(ascii_url, strict = FALSE)))
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

test_that("mixed ASCII, Unicode, and xn labels preserve strict decode behavior", {
  inputs <- c("example.com", "xn--caf-dma.com", "bücher.de")

  expect_equal(
    puny_decode(inputs, strict = TRUE),
    c("example.com", "café.com", "bücher.de")
  )
  expect_equal(
    puny_encode(inputs, strict = TRUE),
    c("example.com", "xn--caf-dma.com", "xn--bcher-kva.de")
  )
})

test_that("strict and non-strict paths handle malformed punycode differently", {
  expect_error(puny_decode("xn--", strict = TRUE), "Error decoding domain")
  expect_true(is.na(puny_decode("xn--", strict = FALSE)))
  expect_error(puny_decode("xn--z", strict = TRUE), "Error decoding domain")
  expect_true(is.na(puny_decode("xn--z", strict = FALSE)))

  expect_error(puny_encode("", strict = TRUE), "Error encoding domain")
  expect_true(is.na(puny_encode("", strict = FALSE)))
})

test_that("strict defaults follow global punycoder.strict option", {
  old <- options(punycoder.strict = FALSE)
  on.exit(options(old), add = TRUE)

  expect_true(is.na(puny_encode("invalid..domain")))
  expect_true(is.na(url_decode("https://xn--.example.com")))

  options(punycoder.strict = TRUE)
  expect_error(puny_encode("invalid..domain"), "Error encoding domain")
  expect_error(url_decode("https://xn--.example.com"), "Error decoding URL")
})

test_that("punycode handles uppercase and trailing dots", {
  expect_equal(puny_decode("XN--CAF-DMA.COM"), "CAFé.COM")
  expect_equal(puny_encode("caf\u00E9.com."), "xn--caf-dma.com.")
  expect_equal(puny_decode("xn--caf-dma.com."), "caf\u00E9.com.")

  expect_warning(decoded <- puny_decode(c("xn--caf-dma.com", NA_character_)))
  expect_equal(decoded[[1]], "café.com")
  expect_true(is.na(decoded[[2]]))
})

test_that("punycode decode reports invalid payload characters", {
  expect_error(puny_decode("xn--ab*", strict = TRUE), "hyphens")
  expect_true(is.na(puny_decode("xn--ab*", strict = FALSE)))
})

test_that("empty string edge cases", {
  expect_error(puny_encode("", strict = TRUE), "Error encoding domain")
  expect_true(is.na(puny_encode("", strict = FALSE)))
  expect_error(puny_decode("", strict = TRUE), "Error decoding domain")
  expect_true(is.na(puny_decode("", strict = FALSE)))
})

test_that("mixed valid/invalid/NA in same vector", {
  expect_warning(
    result <- puny_encode(
      c("example.com", "invalid..com", NA, "caf\u00E9.com"),
      strict = FALSE
    )
  )
  expect_equal(result[1], "example.com")
  expect_true(is.na(result[2]))
  expect_true(is.na(result[3]))
  expect_equal(result[4], "xn--caf-dma.com")
})
