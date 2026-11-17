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
# actually guards the O(n^2) reference decoder and the per-label loops in the
# normalizer.
#
# Real performance work belongs in a dedicated benchmark run against a clean
# `/bin/sh -c 'rm -f src/*.o; R CMD INSTALL .'` build -- never against these
# numbers.

# `system.time()` reports elapsed time in whole milliseconds, so any workload
# that finishes faster than that reads as exactly 0. The short input of the
# scaling test below is one: 4000 short ASCII hosts encode in well under a
# millisecond on a release build, and read 0 on roughly half of all runs.
#
# That matters because the estimator takes the *minimum* of several timings, so
# one 0 reading is enough to drag the result to 0. An earlier version of this
# helper floored the result at `.Machine$double.eps` to keep callers from
# dividing by zero, which quietly reported "too fast to measure" as "infinitely
# fast" -- roughly 1e-14 of any real timing. Ratios built on that could not be
# satisfied by any input, so the scaling test failed with a threshold of 2e-20
# rather than the honest ~1 it was written to check.
#
# So batch the call until the batch clears the timer's resolution, then divide
# the batch count back out. Ten milliseconds keeps the quantization error under
# 10%, far inside the 4x tolerance the scaling assertion allows.
timer_resolution_floor <- 0.01
max_batch <- 256L

benchmark_seconds <- function(fn, input, iterations = 5L) {
  # Warm up so lazy loading and first-touch allocation stay out of the timing.
  fn(input[seq_len(min(length(input), 128L))])

  batch <- 1L
  repeat {
    timings <- vapply(
      seq_len(iterations),
      function(i) system.time(for (b in seq_len(batch)) fn(input))[["elapsed"]],
      numeric(1)
    )

    # Minimum, not median: noise only ever adds time, so the fastest run is the
    # closest estimate of the true cost.
    fastest <- min(timings)

    if (fastest >= timer_resolution_floor) {
      return(fastest / batch)
    }
    if (batch >= max_batch) {
      break
    }
    batch <- batch * 2L
  }

  # Unreachable for any input these tests use -- 256 batches of a 4000-element
  # vector is many seconds of work. If it ever does happen the workload is
  # genuinely below the timer's resolution, and the only honest answer is that
  # this machine cannot measure it. Skipping says so; a floored epsilon would
  # invent a number instead.
  testthat::skip(
    sprintf(
      "timer resolution too coarse to measure this workload (%d batches, %g s)",
      batch,
      fastest
    )
  )
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
#
# `copies` and `long_copies` are how many times each host is repeated to make
# a batch worth timing. 4000 of each suits hosts of a few hundred characters.
# For a long host that is a batch on its own, repeat the short one so the two
# inputs hold about the same number of characters: then both clear
# benchmark_seconds()'s timer floor together, and neither can skip on a fast
# build while the other measures.
expect_cost_per_char_stable <- function(fn, short, long, tolerance = 4,
                                        copies = 4000L, long_copies = copies) {
  short_input <- rep(short, copies)
  long_input <- rep(long, long_copies)

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

test_that("an over-long non-ASCII label is rejected in linear time", {
  skip_on_cran()

  # PUNY-ttjakmgu. host_normalize() used to run the Punycode encoder, then
  # O(n * distinct non-basic code points), before the 63/253-octet check that
  # rejects the result: a 96 KB label of 32,000 distinct Hangul and CJK code
  # points took 1.7 s on an -O2 build to come back NA. The encoder is now
  # O(n log n) (PUNY-yndiwtxb), so this test still bounds the time of the
  # early-rejection path but no longer proves that the rejection happens
  # before encoding; that is tracked separately.
  cjk <- c(0xAC00 + 0:11171, 0x4E00 + 0:20827) # Hangul syllables, then CJK
  short <- intToUtf8(cjk[seq(1L, 32000L, by = 16L)])
  long <- intToUtf8(cjk[seq_len(32000L)])
  expect_identical(nchar(long), 32000L)

  expect_identical(host_normalize(long), NA_character_)

  # Loose absolute bound, as for the combining-mark run in test-normalize.R:
  # it failed at -O0 against the old quadratic encoder and passes with a wide
  # margin now. Not a benchmark. Timed directly, before
  # the scaling check, so a skip there cannot drop it.
  elapsed <- system.time(host_normalize(long))[["elapsed"]]
  expect_lt(elapsed, 0.5)

  # 16 copies of the 2,000-code-point host against one 32,000-code-point host:
  # the same number of characters on each side.
  expect_cost_per_char_stable(
    host_normalize, short, long, copies = 16L, long_copies = 1L
  )
})

test_that("an over-long non-ASCII label encodes in O(n log n) time", {
  skip_on_cran()

  # PUNY-yndiwtxb. With verify_dns_length = FALSE no length check rejects the
  # label, so the encoder itself must be sub-quadratic. The RFC 3492 loop it
  # replaced cost O(n * distinct non-basic code points): 1.7 s on an -O2
  # build for this 32,000-code-point label, every code point distinct. Same
  # inputs as the rejection test above, so a quadratic encoder again makes
  # the long label's cost per character 16x the short one's.
  cjk <- c(0xAC00 + 0:11171, 0x4E00 + 0:20827) # Hangul syllables, then CJK
  short <- intToUtf8(cjk[seq(1L, 32000L, by = 16L)])
  long <- intToUtf8(cjk[seq_len(32000L)])
  encode <- function(x) host_normalize(x, verify_dns_length = FALSE)

  # The result is unchanged: recorded from the quadratic loop.
  out <- encode(long)
  expect_identical(nchar(out), 96992L)
  path <- tempfile()
  on.exit(unlink(path))
  writeBin(charToRaw(out), path)
  expect_identical(
    unname(tools::md5sum(path)), "8f555e112d7a19dcc28625b9dc5eb6cb"
  )

  # Loose absolute bound, as above. Not a benchmark.
  elapsed <- system.time(encode(long))[["elapsed"]]
  expect_lt(elapsed, 0.5)

  expect_cost_per_char_stable(
    encode, short, long, copies = 16L, long_copies = 1L
  )
})

test_that("a non-ASCII label over 59 code points is rejected before encoding", {
  skip_on_cran()

  # PUNY-ttjakmgu. An encoded label is at least 4 + n octets, so a non-ASCII
  # label of more than 59 code points cannot fit 63 and is rejected without
  # being encoded. The test above cannot see that bound: its hosts are over
  # 253 code points, so the host bound rejects them first. Here the long label
  # is 250 distinct code points, under the host bound, and the short one is
  # 10, which encodes. Rejecting the long label costs about a quarter of the
  # short one's per character at -O0; encoding it too costs about four times
  # as much. So the tolerance is 1, not the helper's 4: the long label must
  # be cheaper per character than one that is encoded, which holds only if it
  # is not encoded.
  hangul <- intToUtf8(0xAC00 + 0:249, multiple = TRUE)
  short <- paste(hangul[1:10], collapse = "")
  long <- paste(hangul, collapse = "")

  expect_identical(host_normalize(long), NA_character_)
  # It is NA for its length alone: with the length check off it encodes.
  expect_gt(nchar(host_normalize(long, verify_dns_length = FALSE)), 63L)

  # 10,000 short hosts against 400 long ones: 100,000 characters each.
  expect_cost_per_char_stable(
    host_normalize, short, long, tolerance = 1,
    copies = 10000L, long_copies = 400L
  )
})
