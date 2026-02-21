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
