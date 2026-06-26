#' Summarize validation results
#'
#' Internal helper used by printing code and tests.
#'
#' @param validation_result Result from validate_domain function
#' @return Character vector with one summary string per domain: \code{"Valid"}
#'   for valid domains, or semicolon-separated error messages for invalid ones.
#' @keywords internal
#' @noRd
get_validation_summary <- function(validation_result) {
  if (!inherits(validation_result, "punycoder_validation")) {
    stop("Input must be a punycoder_validation object", call. = FALSE)
  }

  ifelse(
    lengths(validation_result$errors) == 0L,
    "Valid",
    vapply(validation_result$errors, paste, character(1), collapse = "; ")
  )
}

#' Print method for punycoder parsed URL results
#'
#' @param x A punycoder_parsed_url object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns \code{x}.
#' @examples
#' \donttest{
#' parsed <- parse_url("https://caf\u00E9.example.com/path")
#' print(parsed)
#' }
#' @keywords internal
#' @export
print.punycoder_parsed_url <- function(x, ...) {
  cat("Punycoder Parsed URL Results\n")
  cat("============================\n\n")

  n <- length(x$scheme)
  for (i in seq_len(n)) {
    cat("URL", i, ":\n")
    cat("  Scheme:  ", if (is.na(x$scheme[i])) "<NA>" else x$scheme[i], "\n")
    cat("  Domain:  ", if (is.na(x$domain[i])) "<NA>" else x$domain[i], "\n")
    if (!is.na(x$port[i])) cat("  Port:    ", x$port[i], "\n")
    cat("  Path:    ", if (is.na(x$path[i])) "<NA>" else x$path[i], "\n")
    if (!is.na(x$query[i])) cat("  Query:   ", x$query[i], "\n")
    if (!is.na(x$fragment[i])) cat("  Fragment:", x$fragment[i], "\n")
    cat("\n")
  }

  invisible(x)
}

#' Print method for punycoder validation results
#'
#' @param x A punycoder_validation object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns \code{x}.
#' @examples
#' result <- validate_domain(c("example.com", "xn--bad-label-"))
#' print(result)
#' @export
print.punycoder_validation <- function(x, ...) {
  cat("Punycoder Domain Validation Results\n")
  cat("==================================\n\n")

  for (i in seq_along(x$domains)) {
    cat("Domain:", x$domains[i], "\n")
    cat("Valid: ", x$valid[i], "\n")

    if (!x$valid[i] && length(x$errors[[i]]) > 0) {
      cat("Errors:\n")
      for (error in x$errors[[i]]) {
        cat("  -", error, "\n")
      }
    }
    cat("\n")
  }

  invisible(x)
}
