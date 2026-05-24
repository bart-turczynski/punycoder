benchmark_rate <- function(fn, input, iterations = 3L) {
  timings <- vapply(
    seq_len(iterations),
    function(i) system.time(fn(input))[["elapsed"]],
    numeric(1)
  )
  elapsed <- max(stats::median(timings), .Machine$double.eps)
  length(input) / elapsed
}

expect_rate_at_least <- function(fn, input, minimum_rate) {
  rate <- benchmark_rate(fn, input)
  testthat::expect_gte(rate, minimum_rate)
}

test_that("ASCII domain throughput stays high for encode and decode", {
  skip_on_cran()

  ascii_domains <- rep(
    c("example.com", "subdomain.example.net", "xn--caf-dma.com"),
    10000
  )

  expect_rate_at_least(puny_encode, ascii_domains, 20000)
  expect_rate_at_least(puny_decode, ascii_domains, 20000)
})

test_that("Unicode domain throughput stays high for encode and decode", {
  skip_on_cran()

  unicode_domains <- rep(c("café.com", "москва.рф", "bücher.de"), 8000)
  ascii_domains <- puny_encode(unicode_domains)

  expect_rate_at_least(puny_encode, unicode_domains, 10000)
  expect_rate_at_least(puny_decode, ascii_domains, 10000)
})

test_that("mixed URL throughput stays high for encode and decode", {
  skip_on_cran()

  unicode_urls <- rep(
    c(
      "https://café.example.com/path?query=value",
      "https://user:pass@παράδειγμα.ελ:8443/path#frag",
      "http://127.0.0.1/path",
      "http://[2001:db8::1]/path"
    ),
    4000
  )
  ascii_urls <- url_encode(unicode_urls)

  expect_rate_at_least(url_encode, unicode_urls, 5000)
  expect_rate_at_least(url_decode, ascii_urls, 5000)
})

test_that("large vector workloads remain scalable for encode and decode", {
  skip_on_cran()

  domains <- rep(c("example.com", "café.com", "москва.рф", "bücher.de"), 15000)
  encoded <- puny_encode(domains)

  expect_rate_at_least(puny_encode, domains, 8000)
  expect_rate_at_least(puny_decode, encoded, 8000)
})
