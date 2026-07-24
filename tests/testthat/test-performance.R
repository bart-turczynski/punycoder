# Performance smoke checks -- NOT a performance tracker.
#
# Read this before tightening anything here.
#
# `devtools::test()` and `devtools::load_all()` compile the native code at `-O0`
# (`pkgbuild::compile_dll()` debug flags; see AGENTS.md "Stale objects"), so
# throughput under the usual dev loop runs an order of magnitude below an
# optimized `R CMD INSTALL` build. CI runners are slower again, and by an amount
# that varies per run. An absolute threshold that is tight enough to catch a
# 25-30% regression on one machine is therefore guaranteed to flake on another.
#
# So the absolute floors below are deliberately loose: they catch a catastrophic
# regression (an accidental reparse per element, a codec that stopped being
# linear) and nothing subtler. Do not read a passing run as evidence that
# performance is good.
#
# The scaling assertions are the build-independent half. They compare the
# package against itself at two input sizes on the same machine in the same run,
# so the optimization level cancels out and they hold anywhere. That is what
# actually guards the O(n^2) reference codec and the per-label loops in the
# normalizer.
#
# Real performance work belongs in a dedicated benchmark run against a clean
# `rm -f src/*.o && R CMD INSTALL .` build -- never against these numbers.

benchmark_seconds <- function(fn, input, iterations = 5L) {
  # Warm up so lazy loading and first-touch allocation stay out of the timing.
  fn(input[seq_len(min(length(input), 128L))])

  timings <- vapply(
    seq_len(iterations),
    function(i) system.time(fn(input))[["elapsed"]],
    numeric(1)
  )

  # Minimum, not median: noise only ever adds time, so the fastest run is the
  # closest estimate of the true cost.
  max(min(timings), .Machine$double.eps)
}

benchmark_rate <- function(fn, input, iterations = 5L) {
  length(input) / benchmark_seconds(fn, input, iterations)
}

expect_rate_at_least <- function(fn, input, minimum_rate) {
  testthat::expect_gte(benchmark_rate(fn, input), minimum_rate)
}

# Per-character cost must not blow up as a host gets longer. A linear pipeline
# keeps roughly constant cost per character; a superlinear one degrades with
# length: cost c*L^2 gives a per-character ratio of L_long/L_short (~20 for the
# inputs used below), against ~1 for a linear pipeline.
#
# What this catches: gross superlinearity -- an accidental quadratic, or a pass
# that re-walks the whole host once per label. What it does not catch: constant-
# factor regressions, however large. A 5x-slower-but-still-linear pipeline
# passes this cleanly. That is by design; see the file header.
#
# `tolerance` is generous because short inputs carry fixed per-call overhead
# that inflates their per-character figure and so compresses the ratio. The bias
# is toward passing, which is the right direction for a test that must not flake
# across machines.
expect_cost_per_char_stable <- function(fn, short, long, tolerance = 4) {
  short_input <- rep(short, 4000L)
  long_input <- rep(long, 4000L)

  short_per_char <-
    benchmark_seconds(fn, short_input) / (length(short_input) * nchar(short))
  long_per_char <-
    benchmark_seconds(fn, long_input) / (length(long_input) * nchar(long))

  testthat::expect_lt(long_per_char, short_per_char * tolerance)
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

test_that("large vector workloads remain scalable for encode and decode", {
  skip_on_cran()

  domains <- rep(c("example.com", "café.com", "москва.рф", "bücher.de"), 15000)
  encoded <- puny_encode(domains)

  expect_rate_at_least(puny_encode, domains, 8000)
  expect_rate_at_least(puny_decode, encoded, 8000)
})

test_that("host_normalize throughput stays high across label kinds", {
  skip_on_cran()

  # host_normalize is the heaviest path in the package -- UTS-46 mapping, NFC,
  # per-label validation, Punycode -- and had no performance coverage at all
  # until PUNY-ktcaptds. All three label kinds are covered because they take
  # materially different routes: ASCII skips Punycode entirely, Unicode encodes,
  # and an A-label decodes and then re-encodes to verify canonical form.
  ascii <- rep(c("example.com", "subdomain.example.net"), 8000)
  unicode <- rep(c("café.com", "münchen.de"), 8000)
  alabels <- rep(c("xn--caf-dma.com", "xn--mnchen-3ya.de"), 8000)

  expect_rate_at_least(host_normalize, ascii, 5000)
  expect_rate_at_least(host_normalize, unicode, 5000)
  expect_rate_at_least(host_normalize, alabels, 5000)
})

test_that("cost per character stays stable as hosts get longer", {
  skip_on_cran()

  # Build-independent: compares the package against itself at two lengths in the
  # same run, so the optimization level cancels out. Catches a codec or
  # normalizer that stopped being linear in input length, which is the failure
  # the absolute floors above are too loose to see.
  short_ascii <- "example.com"
  long_ascii <- paste(rep("abcdefghij", 20), collapse = ".")

  expect_cost_per_char_stable(puny_encode, short_ascii, long_ascii)
  expect_cost_per_char_stable(host_normalize, short_ascii, long_ascii)

  short_unicode <- "café.com"
  long_unicode <- paste(rep("caféchen", 20), collapse = ".")

  expect_cost_per_char_stable(puny_encode, short_unicode, long_unicode)
  expect_cost_per_char_stable(host_normalize, short_unicode, long_unicode)
})
