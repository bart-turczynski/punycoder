test_that("backend info exposes availability and selected backend", {
  info <- punycoder:::.backend_info()

  expect_named(info, c("automatic", "has_libidn2"))
  expect_type(info$automatic, "character")
  expect_type(info$has_libidn2, "logical")
  expect_length(info$has_libidn2, 1)
})

test_that("fallback and libidn2 agree on RFC 3492 vectors", {
  info <- punycoder:::.backend_info()
  skip_if(!info$has_libidn2, "libidn2 backend is not available")

  vectors <- read.csv(
    system.file("testdata", "rfc3492_vectors.csv", package = "punycoder"),
    stringsAsFactors = FALSE
  )

  encoded <- punycoder:::.compare_backends(
    vectors$unicode,
    "encode_domain",
    strict = FALSE
  )
  expect_true(encoded$available)
  expect_equal(encoded$fallback, encoded$libidn2)

  decoded <- punycoder:::.compare_backends(
    vectors$ascii,
    "decode_domain",
    strict = FALSE
  )
  expect_equal(decoded$fallback, decoded$libidn2)
})

test_that("fallback and libidn2 agree on representative URL cases", {
  info <- punycoder:::.backend_info()
  skip_if(!info$has_libidn2, "libidn2 backend is not available")

  unicode_urls <- c(
    "https://café.example.com/path?query=value",
    "https://user:pass@παράδειγμα.ελ:8443/path#frag",
    "http://127.0.0.1/path",
    "http://[2001:db8::1]/path"
  )
  encoded <- punycoder:::.compare_backends(
    unicode_urls,
    "encode_url",
    strict = TRUE
  )
  expect_equal(encoded$fallback, encoded$libidn2)

  ascii_urls <- c(
    "https://xn--caf-dma.example.com/path",
    "https://user:pass@xn--hxajbheg2az3al.xn--qxam:8443/path#frag",
    "http://127.0.0.1/path",
    "http://[2001:db8::1]/path"
  )
  decoded <- punycoder:::.compare_backends(
    ascii_urls,
    "decode_url",
    strict = TRUE
  )
  expect_equal(decoded$fallback, decoded$libidn2)
})
