test_that(
  "startup hooks preserve explicit options and initialize missing ones",
  {
    old <- options(
      punycoder.strict = FALSE,
      punycoder.encoding = "latin1"
    )
    on.exit(options(old), add = TRUE)

    punycoder:::.onLoad("", "punycoder")
    expect_false(getOption("punycoder.strict"))
    expect_equal(getOption("punycoder.encoding"), "latin1")

    options(punycoder.strict = NULL, punycoder.encoding = NULL)
    punycoder:::.onLoad("", "punycoder")
    expect_true(getOption("punycoder.strict"))
    expect_equal(getOption("punycoder.encoding"), "UTF-8")
  }
)

test_that("attach and unload hooks are callable without side effects", {
  startup_called <- FALSE
  unload_called <- FALSE

  attach_fn <- punycoder:::.onAttach
  attach_env <- new.env(parent = environment(attach_fn))
  attach_env$interactive <- function() TRUE
  attach_env$packageStartupMessage <- function(...) {
    startup_called <<- TRUE
  }
  environment(attach_fn) <- attach_env
  attach_fn("", "punycoder")
  expect_true(startup_called)

  unload_fn <- punycoder:::.onUnload
  unload_env <- new.env(parent = environment(unload_fn))
  unload_env$library.dynam.unload <- function(...) {
    unload_called <<- TRUE
  }
  environment(unload_fn) <- unload_env
  unload_fn("")
  expect_true(unload_called)
})
