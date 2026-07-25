# Parser for the official UTS #46 corpus (inst/testdata/IdnaTestV2.txt).
# Format reference: the file header (Columns c1..c7, status-code legend).
# Kept in a helper so the conformance test reads as assertions, not parsing.

# Unescape \uXXXX and \x{H+} to the actual character, positionally (so a
# replacement that is itself a backslash cannot be misinterpreted).
.idna_unescape <- function(s) {
  pat <- "\\\\x\\{[0-9A-Fa-f]+\\}|\\\\u[0-9A-Fa-f]{4}"
  m <- gregexpr(pat, s, perl = TRUE)[[1]]
  if (m[1] == -1) return(s)
  lens <- attr(m, "match.length")
  out <- ""
  prev <- 1L
  for (i in seq_along(m)) {
    st <- m[i]
    out <- paste0(out, substr(s, prev, st - 1L))
    tok <- substr(s, st, st + lens[i] - 1L)
    hex <- gsub("[\\\\xu{}]", "", tok)
    out <- paste0(out, intToUtf8(strtoi(hex, 16L)))
    prev <- st + lens[i]
  }
  paste0(out, substr(s, prev, nchar(s)))
}

# Rows whose source contains an unpaired surrogate are ill-formed; per the
# file's CONFORMANCE notes, implementations that cannot represent them skip it.
.idna_has_surrogate <- function(s) {
  grepl("\\\\u[Dd][89ABabCDcdEFef][0-9A-Fa-f]{2}", s)
}

# Does a (resolved) status field carry at least one code, e.g. "[A4_2]"?
# A blank field or an explicit "[]" means no error.
.idna_has_codes <- function(stat) {
  br <- regmatches(stat, regexpr("\\[.*\\]", stat))
  if (length(br) == 0L) return(FALSE)
  nzchar(trimws(gsub("^\\[|\\]$", "", br)))
}

# Extract the set of status codes from a resolved status field, e.g.
# "[V3, A4_2]" -> c("V3", "A4_2"). Returns character(0) for a blank or "[]".
.idna_codes <- function(stat) {
  br <- regmatches(stat, regexpr("\\[.*\\]", stat))
  if (length(br) == 0L) return(character(0))
  inner <- trimws(gsub("^\\[|\\]$", "", br))
  if (!nzchar(inner)) return(character(0))
  trimws(strsplit(inner, ",", fixed = TRUE)[[1]])
}

# Parse IdnaTestV2.txt into a data.frame with the resolved non-transitional
# ToASCII expectation. Columns: source, to_ascii (resolved toAsciiN string),
# status (resolved toAsciiNStatus). Ill-formed (surrogate) rows are dropped.
idna_load_v2 <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  src <- character(0)
  asc <- character(0)
  sts <- character(0)
  for (ln in lines) {
    ln <- sub("#.*$", "", ln)              # strip trailing comment
    if (!nzchar(trimws(ln))) next
    parts <- strsplit(ln, ";", fixed = TRUE)[[1]]
    length(parts) <- 7L
    parts[is.na(parts)] <- ""
    f <- trimws(parts)
    c1 <- f[1]
    c2 <- f[2]
    c3 <- f[3]
    c4 <- f[4]
    c5 <- f[5]
    if (.idna_has_surrogate(c1)) next
    source <- if (identical(c1, '""')) "" else .idna_unescape(c1)
    # toAsciiN: explicit "" = empty; blank = inherit toUnicode, then source.
    if (identical(c4, '""')) {
      a <- ""
    } else if (nzchar(c4)) {
      a <- .idna_unescape(c4)
    } else if (identical(c2, '""')) {
      a <- ""
    } else if (nzchar(c2)) {
      a <- .idna_unescape(c2)
    } else {
      a <- source
    }
    # toAsciiNStatus: blank inherits toUnicodeStatus.
    stat <- if (nzchar(c5)) c5 else c3
    src <- c(src, source)
    asc <- c(asc, a)
    sts <- c(sts, stat)
  }
  data.frame(
    source = src, to_ascii = asc, status = sts, stringsAsFactors = FALSE
  )
}

# Status codes a profile must IGNORE when a flag is false (file legend).
# v1 ships strict (all flags true) -> ignore nothing. This hook lets B reuse the
# corpus for relaxed profiles without re-deriving expectations.
.idna_flag_codes <- list(
  verify_dns_length = c("A4_1", "A4_2"),
  check_hyphens     = c("V2", "V3"),
  check_joiners     = "C",   # Cn
  check_bidi        = "B",   # Bn
  use_std3          = "U1"
)
