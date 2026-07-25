# Two generated Unicode table sets are compiled into one shared object and
# selected at compile time; host_normalize_one() dispatches on the version once
# per host and everything past that branch is bound to one table set
# (PUNY-kfpxsquq, ADR-015).
#
# The hooks used here are internal on purpose. The public surface pins one
# Unicode version -- picking one per call is separate work -- but without a way
# to reach the non-default instantiation from R, half the shipped table code
# would never be executed by the test suite at all.
#
# This file is ASCII-clean: every non-ASCII input comes from the fixture or from
# an explicit intToUtf8() of a named code point.

test_that("every shipped table set reports its own registry version", {
  info <- punycoder:::.unicode_versions()

  expect_gt(length(info$version), 1L) # two versions coexisting is the point
  expect_false(anyDuplicated(info$version) > 0L)
  expect_true(info$default %in% info$version)

  # The facade forwards to its own table unit. Pair a version with the wrong
  # facade in PUNYCODER_UNICODE_VERSIONS and these disagree. This also fails
  # (by stack overflow, immediately) if the generator ever emits an unqualified
  # forwarder body, since inside the struct the member name hides the
  # namespace-scope one and the body becomes infinite recursion.
  expect_identical(info$reported, info$version)
})

test_that("the default table set is the one the profile reports", {
  info <- punycoder:::.unicode_versions()
  expect_identical(normalization_profile_info()$unicode_version, info$default)
})

test_that("selecting the default version reproduces host_normalize exactly", {
  x <- c("Example.COM", "example.com.", "a_b.com", "xn--mnchen-3ya.de",
         "not..valid", "", NA_character_)
  default <- punycoder:::.unicode_versions()$default

  expect_identical(punycoder:::.host_normalize_version(x, default),
                   host_normalize(x))
  # ... and under a relaxed profile too: the version rides on the same options
  # struct as the flags, so a mix-up there would show up only here.
  expect_identical(
    punycoder:::.host_normalize_version(x, default, use_std3 = FALSE),
    host_normalize(x, use_std3 = FALSE)
  )
})

test_that("an unshipped Unicode version is a caller error, not NA", {
  # host_normalize()'s NA-on-invalid contract covers invalid host DATA. A
  # version that was never compiled in is a bad argument, so it stops.
  expect_error(punycoder:::.host_normalize_version("example.com", "15.0.0"),
               "Unsupported Unicode version")
  expect_error(punycoder:::.host_normalize_version("example.com", "16"),
               "Unsupported Unicode version")
})

test_that("each shipped table set is idempotent over the conformance corpus", {
  path <- system.file("testdata", "IdnaTestV2.txt", package = "punycoder")
  skip_if(!nzchar(path), "IdnaTestV2.txt fixture not installed")

  corpus <- idna_v2_corpus(path)
  expect_gt(length(corpus), 6000L)

  for (v in punycoder:::.unicode_versions()$version) {
    once <- punycoder:::.host_normalize_version(corpus, v)
    keep <- !is.na(once)
    twice <- punycoder:::.host_normalize_version(once[keep], v)
    expect_identical(twice, once[keep],
                     info = paste("not idempotent under Unicode", v))
  }
})

test_that("16.0.0 and 17.0.0 agree except on code points 17.0.0 assigns", {
  path <- system.file("testdata", "IdnaTestV2.txt", package = "punycoder")
  skip_if(!nzchar(path), "IdnaTestV2.txt fixture not installed")

  corpus <- idna_v2_corpus(path)
  v16 <- punycoder:::.host_normalize_version(corpus, "16.0.0")
  v17 <- punycoder:::.host_normalize_version(corpus, "17.0.0")

  same <- (is.na(v16) & is.na(v17)) | (!is.na(v16) & !is.na(v17) & v16 == v17)
  delta <- corpus[!same]

  # U+32931 and U+32B9A are in CJK Unified Ideographs Extension J
  # (U+323B0..U+3347F), added in Unicode 17.0.0. Under 16.0.0 they are
  # unassigned, so UTS #46 maps them to disallowed and the host is NA; under
  # 17.0.0 they are PVALID and the host normalizes. Every difference between
  # the two table sets on this corpus is of that one kind -- a newly assigned
  # code point going NA -> value, never a value changing.
  expect_true(all(is.na(v16[!same])))
  expect_false(any(is.na(v17[!same])))
  expect_length(delta, 3L)

  new_in_17 <- intToUtf8(c(0x32931L, 0x32B9AL), multiple = TRUE)
  expect_true(all(is.na(punycoder:::.host_normalize_version(new_in_17,
                                                            "16.0.0"))))
  expect_false(any(is.na(punycoder:::.host_normalize_version(new_in_17,
                                                             "17.0.0"))))
})
