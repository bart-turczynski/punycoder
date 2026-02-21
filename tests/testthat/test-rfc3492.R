test_that("RFC 3492 vectors encode to expected punycode", {
  vectors <- read.csv(
    system.file("testdata", "rfc3492_vectors.csv", package = "punycoder"),
    stringsAsFactors = FALSE
  )

  # RFC vectors include generic strings, not only DNS-valid labels.
  encoded <- puny_encode(vectors$unicode, strict = FALSE)
  expect_equal(encoded, vectors$ascii)
})

test_that("RFC 3492 vectors decode to expected unicode", {
  vectors <- read.csv(
    system.file("testdata", "rfc3492_vectors.csv", package = "punycoder"),
    stringsAsFactors = FALSE
  )

  decoded <- puny_decode(vectors$ascii, strict = FALSE)
  expect_equal(decoded, vectors$unicode)
})
