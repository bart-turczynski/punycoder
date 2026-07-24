#' Summarize validation results
#'
#' Internal helper retained for tests.
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

# Maximum number of per-domain blocks print.punycoder_validation emits.
.validation_print_max <- 10L

# Format a count for console display with thousands separators.
# @keywords internal
# @noRd
.fmt_count <- function(n) {
  formatC(n, big.mark = ",", format = "d")
}

# Strict flag recorded on a validation object; NA when the attribute is absent.
# @keywords internal
# @noRd
.validation_strict <- function(x) {
  strict <- attr(x, "strict")
  if (is.null(strict)) NA else strict
}

#' Print method for punycoder validation results
#'
#' Prints a count header followed by one block per domain, truncated to the
#' first 10 elements. Error bullets carry the machine-readable error code in
#' brackets; use \code{\link[=summary.punycoder_validation]{summary()}} for
#' counts by error code across the whole vector.
#'
#' @param x A punycoder_validation object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns \code{x}.
#' @seealso \code{\link{summary.punycoder_validation}} for the aggregate view.
#' @examples
#' result <- validate_domain(c("example.com", "xn--bad-label-"))
#' print(result)
#' @export
print.punycoder_validation <- function(x, ...) {
  n <- length(x$domains)
  n_valid <- sum(x$valid)

  cat("Punycoder Domain Validation Results\n")
  cat("==================================\n\n")
  cat(sprintf(
    "%s domains: %s valid, %s invalid (strict = %s)\n\n",
    .fmt_count(n), .fmt_count(n_valid), .fmt_count(n - n_valid),
    .validation_strict(x)
  ))

  for (i in seq_len(min(n, .validation_print_max))) {
    cat("Domain:", x$domains[i], "\n")
    cat("Valid: ", x$valid[i], "\n")

    if (!x$valid[i] && length(x$errors[[i]]) > 0) {
      cat("Errors:\n")
      messages <- x$errors[[i]]
      codes <- if (is.null(x$error_codes)) character() else x$error_codes[[i]]
      for (j in seq_along(messages)) {
        code <- if (j <= length(codes)) codes[[j]] else NA_character_
        if (is.na(code)) {
          cat("  -", messages[[j]], "\n")
        } else {
          cat("  - ", messages[[j]], " [", code, "]\n", sep = "")
        }
      }
    }
    cat("\n")
  }

  if (n > .validation_print_max) {
    cat(sprintf(
      "... and %s more. Use summary() for counts by error code.\n",
      .fmt_count(n - .validation_print_max)
    ))
  }

  invisible(x)
}

#' Summarize punycoder validation results
#'
#' Condenses a \code{punycoder_validation} object into counts of failures by
#' machine-readable error code. The per-domain detail stays available on the
#' validation object itself (\code{$errors} / \code{$error_codes}) and in
#' \code{\link{print.punycoder_validation}}.
#'
#' @param object A punycoder_validation object
#' @param ... Additional arguments (ignored)
#' @return A data frame of class \code{"punycoder_validation_summary"} with one
#'   row per distinct error code, sorted by count descending, and columns:
#'   \describe{
#'     \item{error_code}{Character; the stable machine-readable error code.}
#'     \item{n}{Integer; how many domains reported that code.}
#'   }
#'   Input with no errors yields a zero-row data frame with the same columns.
#'   The result carries the attributes \code{n} (number of domains),
#'   \code{n_valid}, \code{n_invalid}, and \code{strict}.
#' @seealso \code{\link{validate_domain}},
#'   \code{\link{print.punycoder_validation}}.
#' @examples
#' result <- validate_domain(c("example.com", "-bad.com", "bad_label.com"))
#' summary(result)
#' @export
summary.punycoder_validation <- function(object, ...) {
  codes <- unlist(object$error_codes, use.names = FALSE)
  if (is.null(codes)) {
    codes <- character()
  }
  counts <- table(codes)

  result <- data.frame(
    error_code = as.character(names(counts)),
    n = as.integer(counts),
    stringsAsFactors = FALSE
  )
  result <- result[order(-result$n, result$error_code), , drop = FALSE]
  row.names(result) <- NULL

  n <- length(object$domains)
  n_valid <- sum(object$valid)
  structure(
    result,
    class = c("punycoder_validation_summary", "data.frame"),
    n = n,
    n_valid = n_valid,
    n_invalid = n - n_valid,
    strict = .validation_strict(object)
  )
}

#' Print method for punycoder validation summaries
#'
#' @param x A punycoder_validation_summary object, as returned by
#'   \code{\link{summary.punycoder_validation}}
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns \code{x}.
#' @examples
#' print(summary(validate_domain(c("example.com", "-bad.com"))))
#' @export
print.punycoder_validation_summary <- function(x, ...) {
  cat(sprintf(
    "Punycoder validation summary (strict = %s)\n", .validation_strict(x)
  ))
  cat(sprintf(
    "%s domains: %s valid, %s invalid\n",
    .fmt_count(attr(x, "n")),
    .fmt_count(attr(x, "n_valid")),
    .fmt_count(attr(x, "n_invalid"))
  ))
  cat("\n")

  if (nrow(x) == 0L) {
    cat("No errors.\n")
    return(invisible(x))
  }

  display <- data.frame(
    error_code = x$error_code,
    n = .fmt_count(x$n),
    stringsAsFactors = FALSE
  )
  print.data.frame(display, row.names = FALSE, right = FALSE)

  invisible(x)
}
