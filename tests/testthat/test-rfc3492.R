test_that("RFC 3492 vectors encode to expected punycode", {
  vectors <- read.csv(
    system.file("testdata", "rfc3492_vectors.csv", package = "punycoder"),
    stringsAsFactors = FALSE
  )

  # RFC vectors include generic strings, not only DNS-valid labels. Strict raw
  # punycode validation does not apply DNS label length limits.
  encoded <- puny_encode(vectors$unicode, strict = TRUE)
  expect_equal(encoded, vectors$ascii)
})

test_that("RFC 3492 vectors decode to expected unicode", {
  vectors <- read.csv(
    system.file("testdata", "rfc3492_vectors.csv", package = "punycoder"),
    stringsAsFactors = FALSE
  )

  decoded <- puny_decode(vectors$ascii, strict = TRUE)
  expect_equal(decoded, vectors$unicode)
})

test_that("raw punycode strict mode does not apply DNS label length limits", {
  vectors <- read.csv(
    system.file("testdata", "rfc3492_vectors.csv", package = "punycoder"),
    stringsAsFactors = FALSE
  )

  dns_valid <- vectors[vectors$description %in% c(
    "Hindi (Devanagari)",
    "Japanese (kanji)"
  ), ]
  expect_true(all(nchar(dns_valid$unicode, type = "bytes") > 63))
  expect_true(all(nchar(dns_valid$ascii, type = "bytes") <= 63))
  expect_equal(
    puny_encode(dns_valid$unicode, strict = TRUE),
    dns_valid$ascii
  )
  expect_true(all(validate_domain(dns_valid$unicode, strict = TRUE)$valid))

  overlong <- vectors[vectors$description == "Korean (Hangul syllables)", ]
  expect_true(nchar(overlong$unicode, type = "bytes") > 63)
  expect_true(nchar(overlong$ascii, type = "bytes") > 63)
  expect_equal(
    puny_encode(overlong$unicode, strict = TRUE),
    overlong$ascii
  )
  expect_equal(
    puny_decode(overlong$ascii, strict = TRUE),
    overlong$unicode
  )
  expect_false(validate_domain(overlong$unicode, strict = TRUE)$valid)
})
