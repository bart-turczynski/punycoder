test_that("internal helper assertions behave as expected", {
  expect_no_error(punycoder:::.assert_character(c("a", "b")))
  expect_error(punycoder:::.assert_character(1), "character vector")

  expect_no_error(punycoder:::.assert_flag(TRUE, "strict"))
  expect_error(
    punycoder:::.assert_flag(c(TRUE, FALSE), "strict"),
    "TRUE or FALSE"
  )
  expect_error(punycoder:::.assert_flag(NA, "strict"), "TRUE or FALSE")

  expect_no_warning(punycoder:::.warn_if_na(c("a", "b")))
  expect_warning(punycoder:::.warn_if_na(c("a", NA_character_)), "NA values")
})

test_that(
  "startup hooks preserve explicit options and initialize missing ones",
  {
  old <- options(
    punycoder.strict = FALSE,
    punycoder.encoding = "latin1"
  )
  on.exit(options(old), add = TRUE)

  punycoder:::.onLoad("", "punycoder")
  expect_false(getOption("punycoder.strict"))
  expect_equal(getOption("punycoder.encoding"), "latin1")

  options(punycoder.strict = NULL, punycoder.encoding = NULL)
  punycoder:::.onLoad("", "punycoder")
  expect_true(getOption("punycoder.strict"))
  expect_equal(getOption("punycoder.encoding"), "UTF-8")
  }
)

test_that("attach and unload hooks are callable without side effects", {
  startup_called <- FALSE
  unload_called <- FALSE

  attach_fn <- punycoder:::.onAttach
  attach_env <- new.env(parent = environment(attach_fn))
  attach_env$interactive <- function() TRUE
  attach_env$packageStartupMessage <- function(...) {
    startup_called <<- TRUE
  }
  environment(attach_fn) <- attach_env
  attach_fn("", "punycoder")
  expect_true(startup_called)

  unload_fn <- punycoder:::.onUnload
  unload_env <- new.env(parent = environment(unload_fn))
  unload_env$library.dynam.unload <- function(...) {
    unload_called <<- TRUE
  }
  environment(unload_fn) <- unload_env
  unload_fn("")
  expect_true(unload_called)
})

test_that("strict and non-strict paths handle malformed punycode differently", {
  expect_error(puny_decode("xn--", strict = TRUE), "Error decoding domain")
  expect_true(is.na(puny_decode("xn--", strict = FALSE)))
  expect_error(puny_decode("xn--z", strict = TRUE), "Error decoding domain")
  expect_true(is.na(puny_decode("xn--z", strict = FALSE)))

  expect_error(puny_encode("", strict = TRUE), "Error encoding domain")
  expect_true(is.na(puny_encode("", strict = FALSE)))
})

test_that(
  "url encode/decode handle userinfo, ports, and malformed authorities",
  {
  encoded <- url_encode(
    "https://user:pass@caf\u00E9.example.com:8443/path?q=1#frag"
  )
  expect_equal(
    encoded,
    "https://user:pass@xn--caf-dma.example.com:8443/path?q=1#frag"
  )
  expect_equal(
    url_decode(encoded),
    "https://user:pass@caf\u00E9.example.com:8443/path?q=1#frag"
  )

  expect_error(
    url_decode("https://xn--.example.com", strict = TRUE),
    "Error decoding URL"
  )
  expect_true(is.na(url_decode("https://xn--.example.com", strict = FALSE)))
  }
)

test_that("parse_url supports domain encoding and invalid inputs", {
  parsed <- parse_url(
    "https://caf\u00E9.example.com:8080/path",
    encode_domains = TRUE
  )
  expect_equal(parsed$domain[[1]], "xn--caf-dma.example.com")
  expect_equal(parsed$port[[1]], 8080L)

  invalid <- parse_url("https://[::1/path")
  expect_true(is.na(invalid$domain[[1]]))
  expect_true(is.na(invalid$scheme[[1]]))
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

test_that("punycode handles uppercase and trailing dots", {
  expect_equal(puny_decode("XN--CAF-DMA.COM"), "CAFé.COM")
  expect_equal(puny_encode("caf\u00E9.com."), "xn--caf-dma.com.")
  expect_equal(puny_decode("xn--caf-dma.com."), "caf\u00E9.com.")

  expect_warning(decoded <- puny_decode(c("xn--caf-dma.com", NA_character_)))
  expect_equal(decoded[[1]], "café.com")
  expect_true(is.na(decoded[[2]]))
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

test_that("punycode decode reports invalid payload characters", {
  expect_error(puny_decode("xn--ab*", strict = TRUE), "hyphens")
  expect_true(is.na(puny_decode("xn--ab*", strict = FALSE)))
})

test_that("url helpers cover authority edge cases", {
  expect_equal(url_encode("mailto:user@example.com"), "mailto:user@example.com")
  expect_equal(url_decode("mailto:user@example.com"), "mailto:user@example.com")
  expect_equal(url_encode("http://@/path"), "http://@/path")
  expect_equal(
    url_encode("http://[::1]:8080/path", strict = FALSE),
    "http://[::1]:8080/path"
  )
  expect_error(url_encode("http://[::1]/path"), "Error encoding URL")
  expect_equal(
    url_encode("http://[::1]/path", strict = FALSE),
    "http://[::1]/path"
  )
  expect_error(url_decode("http://[::1]/path"), "Error decoding URL")
  expect_equal(
    url_decode("http://[::1]/path", strict = FALSE),
    "http://[::1]/path"
  )
  expect_error(url_decode("", strict = TRUE), "Error decoding URL")
  expect_true(is.na(url_decode("", strict = FALSE)))

  expect_equal(
    url_encode("http://example.com:abc/path", strict = FALSE),
    "http://[example.com:abc]/path"
  )
  expect_error(
    url_encode("http://[::1]x/path", strict = TRUE),
    "Invalid authority"
  )
  expect_true(is.na(url_encode("http://[::1]x/path", strict = FALSE)))
  expect_true(is.na(url_encode("", strict = FALSE)))
  expect_error(url_encode("", strict = TRUE), "Empty URL")
})

test_that("parse_url covers invalid inputs and encoding fallbacks", {
  expect_true(is.na(parse_url("")$scheme[[1]]))

  bad_host <- rawToChar(as.raw(c(0xC2, 0x20)))
  Encoding(bad_host) <- "bytes"
  bad_url <- paste0("http://", bad_host, ".com/path")
  parsed <- parse_url(bad_url, encode_domains = TRUE)
  expect_true(is.na(parsed$domain[[1]]))
})

test_that("url_encode non-strict catches malformed byte domains", {
  bad_host <- rawToChar(as.raw(c(0xC2, 0x20)))
  Encoding(bad_host) <- "bytes"
  bad_url <- paste0("http://", bad_host, ".com/path")

  expect_error(url_encode(bad_url, strict = TRUE), "Error encoding URL")
  expect_true(is.na(url_encode(bad_url, strict = FALSE)))
})

test_that("invalid UTF-8 byte sequences return NA in non-strict mode", {
  bad_seq <- function(bytes) {
    x <- rawToChar(as.raw(bytes))
    Encoding(x) <- "bytes"
    paste0(x, ".com")
  }

  expect_true(is.na(puny_encode(bad_seq(c(0xF8, 0x80, 0x80, 0x80, 0x80)),
    strict = FALSE)))
  expect_true(is.na(puny_encode(bad_seq(c(0xE2)), strict = FALSE)))
  expect_true(is.na(puny_encode(bad_seq(c(0xC2, 0x20)), strict = FALSE)))
  expect_true(is.na(puny_encode(bad_seq(c(0xC0, 0x80)), strict = FALSE)))
  expect_true(is.na(puny_encode(bad_seq(c(0xED, 0xA0, 0x80)), strict = FALSE)))
})

test_that("3-byte and 4-byte code points round-trip", {
  three_byte <- "\u5317\u4EAC.com"
  four_byte <- "\U0001F600.com"

  expect_equal(puny_decode(puny_encode(three_byte)), three_byte)
  expect_equal(puny_decode(puny_encode(four_byte)), four_byte)
})
