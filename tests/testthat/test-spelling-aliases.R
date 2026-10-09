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
  expect_identical(info$profile, "uts46-nontransitional-std3-v3")
  expect_true(info$use_std3)
  expect_identical(
    normalization_profile_info(check_hyphens = FALSE)$profile,
    "uts46-nontransitional-std3-v3+no-check-hyphens"
  )
})

# --- British-spelling aliases ---------------------------------------------

.alias_exports <- getNamespaceExports("punycoder")

test_that("host_normalise() is host_normalize()", {
  expect_identical(host_normalise, host_normalize)
  expect_true("host_normalise" %in% .alias_exports)
  expect_identical(host_normalise(.alias_hosts), .alias_hosts_expected)
  expect_identical(host_normalise("a_b.com", use_std3 = FALSE), "a_b.com")
})

test_that("normalisation_profile_info() is normalization_profile_info()", {
  expect_identical(normalisation_profile_info, normalization_profile_info)
  expect_true("normalisation_profile_info" %in% .alias_exports)
  expect_identical(
    normalisation_profile_info(), normalization_profile_info()
  )
  expect_identical(
    normalisation_profile_info(check_hyphens = FALSE)$profile,
    "uts46-nontransitional-std3-v3+no-check-hyphens"
  )
})

test_that("each alias is documented on its US name's help page", {
  # Reads the source tree's man/, so it runs under devtools::test() and skips
  # in an installed-package check, where R CMD check's own codoc covers it.
  man_dir <- test_path("..", "..", "man")
  skip_if_not(dir.exists(man_dir), "man/ not in tree")
  rd_aliases <- function(page) {
    rd <- tools::parse_Rd(file.path(man_dir, paste0(page, ".Rd")))
    tags <- vapply(rd, attr, character(1L), "Rd_tag")
    vapply(rd[tags == "\\alias"], as.character, character(1L))
  }
  expect_true("host_normalise" %in% rd_aliases("host_normalize"))
  expect_true(
    "normalisation_profile_info" %in% rd_aliases("normalization_profile_info")
  )
})
