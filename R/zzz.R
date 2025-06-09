.onLoad <- function(libname, pkgname) {
  # Register native routines for C++ functions
  # This is done automatically by Rcpp, but we can add custom initialization here
  
  # Set default options for the package
  options(
    punycoder.strict = TRUE,
    punycoder.encoding = "UTF-8"
  )
}

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "punycoder: Unicode and Punycode Domain Name Processing\n",
    "Type ?punycoder for help or see vignette('punycoder-intro')\n",
    "Report issues at: https://github.com/yourusername/punycoder/issues"
  )
}

.onUnload <- function(libpath) {
  # Clean up any resources when package is unloaded
  library.dynam.unload("punycoder", libpath)
} 