# Two generated Unicode table sets are compiled into one shared object and
# selected at compile time; host_normalize_one() dispatches on the version once
# per host and everything past that branch is bound to one table set
# (PUNY-kfpxsquq, ADR-015).
#
# Selection is public as of PUNY-wjlfpppq: host_normalize(unicode_version=) and
# unicode_versions(). One internal hook remains, .unicode_version_info(), which
# additionally exposes what each table unit reports about ITSELF -- the public
# function deliberately does not, since only a wiring test needs it.
#
# This file is ASCII-clean: every non-ASCII input comes from the fixture or from
# an explicit intToUtf8() of a named code point.

test_that("every shipped table set reports its own registry version", {
  info <- punycoder:::.unicode_version_info()

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

test_that("unicode_versions() reports the shipped set", {
  expect_identical(unicode_versions(),
                   punycoder:::.unicode_version_info()$version)
  expect_type(unicode_versions(), "character")
})

test_that("the default table set is the one the profile reports", {
  info <- punycoder:::.unicode_version_info()
  expect_identical(normalization_profile_info()$unicode_version, info$default)
  # NULL is the only implicit answer, and it means the pin -- not "whatever is
  # newest", which would change behavior under the caller on a version bump.
  expect_identical(host_normalize("Example.COM", unicode_version = NULL),
                   host_normalize("Example.COM",
                                  unicode_version = info$default))
})

test_that("selecting the default version reproduces host_normalize exactly", {
  x <- c("Example.COM", "example.com.", "a_b.com", "xn--mnchen-3ya.de",
         "not..valid", "", NA_character_)
  default <- punycoder:::.unicode_version_info()$default

  expect_identical(host_normalize(x, unicode_version = default),
                   host_normalize(x))
  # ... and under a relaxed profile too: the version rides on the same options
  # struct as the flags, so a mix-up there would show up only here.
  expect_identical(
    host_normalize(x, use_std3 = FALSE, unicode_version = default),
    host_normalize(x, use_std3 = FALSE)
  )
})

test_that("names are preserved when a version is selected", {
  x <- c(a = "Example.COM", b = "über.de")
  expect_named(host_normalize(x, unicode_version = "17.0.0"), c("a", "b"))
})

test_that("an unshipped Unicode version is an actionable error, not NA", {
  # host_normalize()'s NA-on-invalid contract covers invalid host DATA. A
  # version that was never compiled in is a bad argument, so it stops -- and it
  # must never silently fall back to the pin, which would let a caller record a
  # profile identity describing a normalization that never ran (PUNY-nblrvplp).
  expect_error(host_normalize("example.com", unicode_version = "15.0.0"),
               "Unsupported Unicode version")
  expect_error(host_normalize("example.com", unicode_version = "16"),
               "Unsupported Unicode version")

  # The message names what IS available, so the fix needs no documentation.
  err <- tryCatch(host_normalize("example.com", unicode_version = "15.0.0"),
                  error = conditionMessage)
  for (v in unicode_versions()) expect_match(err, v, fixed = TRUE)

  expect_error(host_normalize("example.com", unicode_version = NA_character_),
               "single non-NA character string")
  expect_error(host_normalize("example.com", unicode_version = 16),
               "single non-NA character string")
  expect_error(host_normalize("example.com",
                              unicode_version = c("16.0.0", "17.0.0")),
               "single non-NA character string")
  expect_error(
    normalization_profile_info(unicode_version = "15.0.0"),
    "Unsupported Unicode version"
  )
})

test_that("the profile token distinguishes a non-default table set", {
  info <- punycoder:::.unicode_version_info()
  other <- setdiff(info$version, info$default)
  skip_if(length(other) == 0L, "build ships only one table set")

  # The pinned default leaves the token bare, at the current profile revision.
  # Compiling in a further table set must never move it; only moving the pin
  # itself does, and then by incrementing -vN (ADR-017).
  expect_identical(normalization_profile_info()$profile,
                   "uts46-nontransitional-std3-v2")
  expect_identical(
    normalization_profile_info(unicode_version = info$default)$profile,
    "uts46-nontransitional-std3-v2"
  )

  # Anything else appends a tag, on the same rule as a relaxed flag, so two
  # genuinely different normalizations can never mint identical() tokens.
  alt <- normalization_profile_info(unicode_version = other[[1L]])
  expect_identical(alt$profile,
                   paste0("uts46-nontransitional-std3-v2+unicode-",
                          other[[1L]]))
  expect_identical(alt$unicode_version, other[[1L]])
  expect_false(identical(alt$profile, normalization_profile_info()$profile))

  # The version tag composes with the flag tags in fixed order.
  expect_identical(
    normalization_profile_info(use_std3 = FALSE,
                               unicode_version = other[[1L]])$profile,
    paste0("uts46-nontransitional-std3-v2+no-std3+unicode-", other[[1L]])
  )
})

test_that("each shipped table set is idempotent over the conformance corpus", {
  # Each engine runs over the corpus Unicode published WITH it, so a version's
  # own newly assigned code points are actually exercised.
  for (v in unicode_versions()) {
    path <- idna_fixture_path(v)
    skip_if(!nzchar(path), paste("IdnaTestV2 fixture not installed for", v))

    corpus <- idna_v2_corpus(path)
    expect_gt(length(corpus), 6000L)

    once <- host_normalize(corpus, unicode_version = v)
    keep <- !is.na(once)
    twice <- host_normalize(once[keep], unicode_version = v)
    expect_identical(twice, once[keep],
                     info = paste("not idempotent under Unicode", v))
  }
})

# The invariant the whole multi-version epic rests on: a Unicode bump is
# provably accept-only for this pipeline (every code point that changed between
# the shipped versions moved OUT of `disallowed`, never into it), so a newer
# table set may newly accept a host but must never reject one an older set
# accepted, nor return a different value for it. That is strictly stronger and
# more durable than any fixed delta count, and it mirrors the "relaxation is
# monotone" assertion the flag knobs get in test-idna-conformance.R.
test_that("a newer table set only ever accepts more, never differently", {
  # Ordered numerically, not with sort(): a lexical sort of version strings
  # breaks the moment a single-digit major is shipped alongside a double-digit
  # one (sort(c("9.0.0", "10.0.0")) puts 10 first), which would pair the
  # versions backwards and assert monotonicity in the wrong direction -- a test
  # that passes while checking the opposite of what it claims.
  versions <- unicode_versions()
  versions <- versions[order(numeric_version(versions))]
  skip_if(length(versions) < 2L, "build ships only one table set")

  for (i in seq_len(length(versions) - 1L)) {
    older <- versions[[i]]
    newer <- versions[[i + 1L]]

    # Run over BOTH corpora: the newer one carries the newly assigned code
    # points, the older one guards the inputs that already worked.
    for (cv in versions) {
      path <- idna_fixture_path(cv)
      skip_if(!nzchar(path), paste("IdnaTestV2 fixture not installed for", cv))

      corpus <- idna_v2_corpus(path)
      a <- host_normalize(corpus, unicode_version = older)
      b <- host_normalize(corpus, unicode_version = newer)
      label <- paste(older, "->", newer, "over the", cv, "corpus")

      # Nothing the older set accepts may become NA under the newer one ...
      expect_false(any(!is.na(a) & is.na(b)), info = label)
      # ... and nothing may come back with a different value.
      expect_false(any(!is.na(a) & !is.na(b) & a != b), info = label)
    }
  }
})

test_that("16.0.0 and 17.0.0 differ only on code points 17.0.0 assigns", {
  # The delta count below is a fact about the 16.0.0 CORPUS specifically (the
  # 17.0.0 corpus adds rows for further newly assigned code points and has a
  # different count), so this test names its corpus rather than looping.
  path <- idna_fixture_path("16.0.0")
  skip_if(!nzchar(path), "IdnaTestV2 fixture not installed for 16.0.0")

  corpus <- idna_v2_corpus(path)
  v16 <- host_normalize(corpus, unicode_version = "16.0.0")
  v17 <- host_normalize(corpus, unicode_version = "17.0.0")

  same <- (is.na(v16) & is.na(v17)) | (!is.na(v16) & !is.na(v17) & v16 == v17)
  delta <- corpus[!same]

  # U+32931 and U+32B9A are in CJK Unified Ideographs Extension J
  # (U+323B0..U+3347F), added in Unicode 17.0.0. Under 16.0.0 they are
  # unassigned, so UTS #46 maps them to disallowed and the host is NA; under
  # 17.0.0 they are PVALID and the host normalizes. Every difference between
  # the two table sets on this corpus is of that one kind -- a newly assigned
  # code point going NA -> value, never a value changing.
  expect_true(all(is.na(v16[!same])))
  expect_false(anyNA(v17[!same]))
  expect_length(delta, 3L)

  new_in_17 <- intToUtf8(c(0x32931L, 0x32B9AL), multiple = TRUE)
  expect_true(all(is.na(host_normalize(new_in_17,
                                            unicode_version = "16.0.0"))))
  expect_false(anyNA(host_normalize(new_in_17, unicode_version = "17.0.0")))
})
