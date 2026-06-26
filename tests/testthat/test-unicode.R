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

test_that("3-byte and 4-byte code points round-trip", {
  three_byte <- "\u5317\u4EAC.com"
  four_byte <- "\U0001F600.com"

  expect_equal(puny_decode(puny_encode(three_byte)), three_byte)
  expect_equal(puny_decode(puny_encode(four_byte)), four_byte)
})
