.onLoad <- function(libname, pkgname) {
  current_strict <- getOption("punycoder.strict")
  if (is.null(current_strict)) {
    options(punycoder.strict = TRUE)
  }

  current_encoding <- getOption("punycoder.encoding")
  if (is.null(current_encoding)) {
    # Preserved for compatibility while the package standardizes on UTF-8.
    options(punycoder.encoding = "UTF-8")
  }
}

.onAttach <- function(libname, pkgname) {
  if (interactive()) {
    packageStartupMessage(
      "punycoder: Unicode and Punycode Domain Name Processing\n",
      "Type ?punycoder for help or see vignette('punycoder-intro')"
    )
  }
}

.onUnload <- function(libpath) {
  # Clean up any resources when package is unloaded
  library.dynam.unload("punycoder", libpath)
}
