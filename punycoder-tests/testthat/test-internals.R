test_that("internal helper assertions behave as expected", {
  expect_no_error(punycoder:::.assert_character(c("a", "b")))
  expect_error(punycoder:::.assert_character(1), "character vector")

  expect_no_error(punycoder:::.assert_flag(TRUE, "strict"))
  expect_error(
    punycoder:::.assert_flag(c(TRUE, FALSE), "strict"),
    "TRUE or FALSE"
  )
  expect_error(punycoder:::.assert_flag(NA, "strict"), "TRUE or FALSE")

  expect_no_warning(punycoder:::.warn_if_na(c("a", "b")))
  expect_warning(punycoder:::.warn_if_na(c("a", NA_character_)), "NA values")
})
