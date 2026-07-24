test_that("invalid UTF-8 byte sequences return NA in non-strict mode", {
  bad_seq <- function(bytes) {
    x <- rawToChar(as.raw(bytes))
    Encoding(x) <- "bytes"
    paste0(x, ".com")
  }

  expect_true(
    is.na(
      puny_encode(
        bad_seq(c(0xF8, 0x80, 0x80, 0x80, 0x80)),
        strict = FALSE
      )
    )
  )
  expect_true(is.na(puny_encode(bad_seq(0xE2), strict = FALSE)))
  expect_true(is.na(puny_encode(bad_seq(c(0xC2, 0x20)), strict = FALSE)))
  expect_true(is.na(puny_encode(bad_seq(c(0xC0, 0x80)), strict = FALSE)))
  expect_true(is.na(puny_encode(bad_seq(c(0xED, 0xA0, 0x80)), strict = FALSE)))
})

test_that("native entry points transcode Latin-1 input to UTF-8", {
  latin1 <- latin1_bytes(0x63, 0x61, 0x66, 0xE9, 0x2E, 0x63, 0x6F, 0x6D)
  utf8 <- "caf\u00E9.com"

  for (strict in c(TRUE, FALSE)) {
    expect_identical(
      puny_encode(latin1, strict = strict),
      "xn--caf-dma.com"
    )

    decoded <- puny_decode(latin1, strict = strict)
    expect_identical(decoded, utf8)

    validation <- validate_domain(latin1, strict = strict)
    expect_true(validation$valid)
    expect_identical(validation$domains, utf8)
    expect_identical(Encoding(validation$domains), "UTF-8")
    expect_identical(validation$errors[[1]], character())
    expect_identical(validation$error_codes[[1]], character())
  }
})

test_that("mixed-encoding vectors are normalized before native dispatch", {
  latin1 <- latin1_bytes(0x63, 0x61, 0x66, 0xE9, 0x2E, 0x63, 0x6F, 0x6D)
  input <- c("example.com", latin1, "b\u00FCcher.de")
  utf8 <- c("example.com", "caf\u00E9.com", "b\u00FCcher.de")

  for (strict in c(TRUE, FALSE)) {
    expect_identical(
      puny_encode(input, strict = strict),
      c("example.com", "xn--caf-dma.com", "xn--bcher-kva.de")
    )
    expect_identical(puny_decode(input, strict = strict), utf8)

    validation <- validate_domain(input, strict = strict)
    expect_true(all(validation$valid))
    expect_identical(validation$domains, utf8)
  }
})

test_that("UTF-8-marked malformed bytes still reach native validation", {
  malformed <- raw_utf8(0xFF)

  expect_error(
    puny_encode(malformed, strict = TRUE),
    "^Error encoding domain: Invalid UTF-8 sequence"
  )
  expect_true(is.na(puny_encode(malformed, strict = FALSE)))

  validation <- validate_domain(malformed)
  expect_false(validation$valid)
  expect_identical(validation$error_codes[[1]], "invalid_utf8_sequence")
})

test_that("3-byte and 4-byte code points round-trip", {
  three_byte <- "\u5317\u4EAC.com"
  four_byte <- "\U0001F600.com"

  expect_identical(puny_decode(puny_encode(three_byte)), three_byte)
  expect_identical(puny_decode(puny_encode(four_byte)), four_byte)
})
