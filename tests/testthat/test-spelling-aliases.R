# Exported names are US English; a British spelling is exported as an alias
# bound to the very same function object (SEOR-qwomlgjd).
#
# The first block pins the current behavior of the two US-spelled functions by
# name, so the alias checks below compare against a known answer rather than
# against whatever the primary happens to return.

.alias_hosts <- c(
  upper = "Example.COM", umlaut = "münchen.de", root = "example.com.",
  std3 = "a_b.com", missing = NA_character_
)
.alias_hosts_expected <- c(
  upper = "example.com", umlaut = "xn--mnchen-3ya.de", root = "example.com.",
  std3 = NA_character_, missing = NA_character_
)

test_that("pin: host_normalize() on representative hosts", {
  expect_identical(host_normalize(.alias_hosts), .alias_hosts_expected)
  expect_identical(host_normalize("a_b.com", use_std3 = FALSE), "a_b.com")
})

test_that("pin: normalization_profile_info() default and relaxed identity", {
  info <- normalization_profile_info()
  expect_identical(info$profile, "uts46-nontransitional-std3-v2")
  expect_true(info$use_std3)
  expect_identical(
    normalization_profile_info(check_hyphens = FALSE)$profile,
    "uts46-nontransitional-std3-v2+no-check-hyphens"
  )
})
