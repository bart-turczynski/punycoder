test_that("encoding throughput baseline exceeds 10k domains per second", {
  skip_on_cran()

  domains <- rep(c("café.com", "москва.рф"), 5000)
  elapsed <- system.time({
    puny_encode(domains)
  })[["elapsed"]]
  elapsed <- max(elapsed, .Machine$double.eps)

  rate <- length(domains) / elapsed
  expect_gte(rate, 10000)
})

test_that("decoding throughput exceeds 10k domains per second", {
  skip_on_cran()

  domains <- rep(c("xn--caf-dma.com", "xn--80adxhks.xn--p1ai"), 5000)
  elapsed <- system.time({
    puny_decode(domains)
  })[["elapsed"]]
  elapsed <- max(elapsed, .Machine$double.eps)

  rate <- length(domains) / elapsed
  expect_gte(rate, 10000)
})
