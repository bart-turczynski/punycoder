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
