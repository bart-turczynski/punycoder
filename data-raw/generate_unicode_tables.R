#!/usr/bin/env Rscript
#
# Generate the vendored Unicode data tables that punycoder's in-tree
# canonical-host normalization depends on (NFC + UTS-46), pinned to one Unicode
# version. See dev/normalization-contract.md (section 0, decision 3).
#
# Run from the package root:  Rscript data-raw/generate_unicode_tables.R
#
# Network access happens HERE, at generation time only. The generated C++
# (src/unicode_tables_16_0_0.{h,cpp}) is committed; the package never downloads
# anything at build or run time. Downloaded UCD files are cached under
# data-raw/.ucd-cache/ (git-ignored).
#
# This pass emits the tables needed by NFC (PSLR-pzeeruwe), UTS-46 mapping +
# label validation (PSLR-pwwtqowh), and the CheckBidi/CheckJoiners label rules
# (PSLR-izaqpicn): canonical combining class, canonical decomposition
# (recursively expanded), canonical composition, the UTS-46 mapping/status
# table, the combining-mark set (for the V5 "label must not begin with a
# combining mark" rule), and the Bidi_Class + Joining_Type properties (for
# RFC 5893 CheckBidi and IDNA2008 ContextJ CheckJoiners).

unicode_version <- "16.0.0"

ucd_base <- sprintf("https://www.unicode.org/Public/%s/ucd", unicode_version)
idna_base <- sprintf("https://www.unicode.org/Public/idna/%s", unicode_version)

cache_dir <- file.path("data-raw", ".ucd-cache")
dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

fetch <- function(name, base) {
  dest <- file.path(cache_dir, name)
  if (!file.exists(dest)) {
    url <- sprintf("%s/%s", base, name)
    message("downloading ", url)
    utils::download.file(url, dest, mode = "wb", quiet = TRUE)
  }
  readLines(dest, encoding = "UTF-8", warn = FALSE)
}

# Strip a trailing "# comment" and surrounding whitespace, return "" for blanks.
strip_comment <- function(lines) {
  lines <- sub("#.*$", "", lines, perl = TRUE)
  trimws(lines)
}

hex <- function(x) strtoi(x, 16L)

# ---------------------------------------------------------------------------
# UnicodeData.txt: canonical combining class (field 3), canonical
# decomposition (field 5, entries WITHOUT a <compat> tag), general category
# (field 2). Handles "First"/"Last" range pairs.
# ---------------------------------------------------------------------------
udata <- fetch("UnicodeData.txt", ucd_base)
udata <- udata[nzchar(udata)]
fields <- strsplit(udata, ";", fixed = TRUE)

cp_vec <- vapply(fields, function(f) hex(f[[1]]), integer(1))
name_vec <- vapply(fields, function(f) f[[2]], character(1))
gc_vec <- vapply(fields, function(f) f[[3]], character(1))
ccc_vec <- vapply(fields, function(f) as.integer(f[[4]]), integer(1))
decomp_f <- vapply(fields, function(f) f[[6]], character(1))

# Expand First/Last range rows into (start, end) spans carrying gc/ccc.
range_start <- grep(", First>$", name_vec)
range_rows <- data.frame(
  lo = integer(0), hi = integer(0), gc = character(0), ccc = integer(0),
  stringsAsFactors = FALSE
)
for (i in range_start) {
  range_rows <- rbind(range_rows, data.frame(
    lo = cp_vec[i], hi = cp_vec[i + 1L], gc = gc_vec[i], ccc = ccc_vec[i],
    stringsAsFactors = FALSE
  ))
}

# --- Canonical combining class (nonzero only; default is 0) ---
ccc_map <- integer(0)
nz <- which(ccc_vec != 0L)
if (length(nz)) ccc_map[as.character(cp_vec[nz])] <- ccc_vec[nz]
# range rows never carry nonzero ccc in practice, but honor them if they do.
for (r in seq_len(nrow(range_rows))) {
  if (range_rows$ccc[r] != 0L) {
    for (cp in range_rows$lo[r]:range_rows$hi[r]) {
      ccc_map[as.character(cp)] <- range_rows$ccc[r]
    }
  }
}

# --- Canonical decomposition (one step; <compat> excluded) ---
canon_decomp <- list()
has_decomp <- which(nzchar(decomp_f) & !grepl("<", decomp_f, fixed = TRUE))
for (i in has_decomp) {
  parts <- strsplit(decomp_f[i], " ", fixed = TRUE)[[1]]
  canon_decomp[[as.character(cp_vec[i])]] <- hex(parts)
}

# Fully expand canonical decomposition recursively (Hangul is algorithmic and
# absent from the file, so it is handled in C++ at runtime, not here).
expand <- function(cp, seen = integer(0)) {
  d <- canon_decomp[[as.character(cp)]]
  if (is.null(d)) {
    return(cp)
  }
  unlist(lapply(d, expand), use.names = FALSE)
}
full_decomp <- lapply(names(canon_decomp), function(k) expand(as.integer(k)))
names(full_decomp) <- names(canon_decomp)

# ---------------------------------------------------------------------------
# DerivedNormalizationProps.txt: Full_Composition_Exclusion. A primary
# canonical decomposition of length 2 yields a composition pair UNLESS the
# composite is fully-composition-excluded.
# ---------------------------------------------------------------------------
dnp <- strip_comment(fetch("DerivedNormalizationProps.txt", ucd_base))
dnp <- dnp[nzchar(dnp)]
fce <- new.env(parent = emptyenv())
for (line in dnp) {
  segs <- trimws(strsplit(line, ";", fixed = TRUE)[[1]])
  if (length(segs) < 2L || segs[[2]] != "Full_Composition_Exclusion") next
  rng <- strsplit(segs[[1]], "..", fixed = TRUE)[[1]]
  lo <- hex(rng[[1]])
  hi <- if (length(rng) > 1L) hex(rng[[2]]) else lo
  for (cp in lo:hi) assign(as.character(cp), TRUE, envir = fce)
}

# --- Canonical composition pairs ---
comp_a <- integer(0)
comp_b <- integer(0)
comp_c <- integer(0)
for (k in names(canon_decomp)) {
  d <- canon_decomp[[k]]
  if (length(d) != 2L) next # singletons never compose
  cp <- as.integer(k)
  if (exists(k, envir = fce, inherits = FALSE)) next
  comp_a <- c(comp_a, d[[1]])
  comp_b <- c(comp_b, d[[2]])
  comp_c <- c(comp_c, cp)
}
ord <- order(comp_a, comp_b)
comp_a <- comp_a[ord]
comp_b <- comp_b[ord]
comp_c <- comp_c[ord]

# ---------------------------------------------------------------------------
# IdnaMappingTable.txt: status + mapping. A ranged "mapped"/"deviation" row maps
# every code point in the range to the same target sequence.
# ---------------------------------------------------------------------------
idna <- strip_comment(fetch("IdnaMappingTable.txt", idna_base))
idna <- idna[nzchar(idna)]

status_code <- c(
  valid = 0L, ignored = 1L, mapped = 2L, deviation = 3L, disallowed = 4L,
  disallowed_STD3_valid = 5L, disallowed_STD3_mapped = 6L
)

idna_lo <- integer(0)
idna_hi <- integer(0)
idna_status <- integer(0)
idna_map <- list()
for (line in idna) {
  segs <- trimws(strsplit(line, ";", fixed = TRUE)[[1]])
  rng <- strsplit(segs[[1]], "..", fixed = TRUE)[[1]]
  lo <- hex(rng[[1]])
  hi <- if (length(rng) > 1L) hex(rng[[2]]) else lo
  st <- segs[[2]]
  mapping <- integer(0)
  if (length(segs) >= 3L && nzchar(segs[[3]])) {
    mapping <- hex(strsplit(segs[[3]], " ", fixed = TRUE)[[1]])
  }
  idna_lo <- c(idna_lo, lo)
  idna_hi <- c(idna_hi, hi)
  idna_status <- c(idna_status, status_code[[st]])
  idna_map[[length(idna_map) + 1L]] <- mapping
}
ord <- order(idna_lo)
idna_lo <- idna_lo[ord]
idna_hi <- idna_hi[ord]
idna_status <- idna_status[ord]
idna_map <- idna_map[ord]

# ---------------------------------------------------------------------------
# Combining marks (general category Mn/Mc/Me) for UTS-46 rule V5.
# ---------------------------------------------------------------------------
is_mark_gc <- function(gc) gc %in% c("Mn", "Mc", "Me")
mark_cps <- cp_vec[is_mark_gc(gc_vec)]
for (r in seq_len(nrow(range_rows))) {
  if (is_mark_gc(range_rows$gc[r])) {
    mark_cps <- c(mark_cps, range_rows$lo[r]:range_rows$hi[r])
  }
}
mark_cps <- sort(unique(mark_cps))

# ---------------------------------------------------------------------------
# Compress a sorted integer vector with associated values into [lo,hi]=value
# ranges. Returns a data.frame(lo, hi, value).
# ---------------------------------------------------------------------------
to_ranges <- function(cps, values) {
  o <- order(cps)
  cps <- cps[o]
  values <- values[o]
  lo <- integer(0)
  hi <- integer(0)
  val <- integer(0)
  i <- 1L
  n <- length(cps)
  while (i <= n) {
    j <- i
    while (j < n && cps[j + 1L] == cps[j] + 1L && values[j + 1L] == values[i]) {
      j <- j + 1L
    }
    lo <- c(lo, cps[i])
    hi <- c(hi, cps[j])
    val <- c(val, values[i])
    i <- j + 1L
  }
  data.frame(lo = lo, hi = hi, value = val)
}

ccc_cps <- as.integer(names(ccc_map))
ccc_ranges <- to_ranges(ccc_cps, unname(ccc_map))
mark_ranges <- to_ranges(mark_cps, rep(1L, length(mark_cps)))

# ---------------------------------------------------------------------------
# Bidi_Class (extracted/DerivedBidiClass.txt) for RFC 5893 CheckBidi and
# Joining_Type (extracted/DerivedJoiningType.txt) for IDNA2008 ContextJ
# CheckJoiners. These files give explicit [lo..hi]; value rows. Only code
# points that survive UTS-46 mapping reach these checks, so unlisted code
# points default to the dominant value (Bidi_Class L, Joining_Type U =
# Non_Joining) in the C++ accessor without affecting any validatable label.
# ---------------------------------------------------------------------------
ucd_extracted <- sprintf("%s/extracted", ucd_base)

parse_prop_ranges <- function(name, base, value_map) {
  lines <- strip_comment(fetch(name, base))
  lines <- lines[nzchar(lines)]
  lo <- integer(0)
  hi <- integer(0)
  val <- integer(0)
  for (line in lines) {
    segs <- trimws(strsplit(line, ";", fixed = TRUE)[[1]])
    rng <- strsplit(segs[[1]], "..", fixed = TRUE)[[1]]
    l <- hex(rng[[1]])
    h <- if (length(rng) > 1L) hex(rng[[2]]) else l
    code <- value_map[[segs[[2]]]]
    if (is.null(code)) stop("unmapped property value: ", segs[[2]])
    lo <- c(lo, l)
    hi <- c(hi, h)
    val <- c(val, code)
  }
  o <- order(lo)
  lo <- lo[o]
  hi <- hi[o]
  val <- val[o]
  # Coalesce adjacent ranges that carry the same value.
  klo <- integer(0)
  khi <- integer(0)
  kval <- integer(0)
  i <- 1L
  n <- length(lo)
  while (i <= n) {
    j <- i
    while (j < n && hi[j] + 1L == lo[j + 1L] && val[j + 1L] == val[i]) {
      j <- j + 1L
    }
    klo <- c(klo, lo[i])
    khi <- c(khi, hi[j])
    kval <- c(kval, val[i])
    i <- j + 1L
  }
  data.frame(lo = klo, hi = khi, value = kval)
}

# Codes must match the C++ BidiClass / JoiningType enums emitted below.
bidi_values <- list(
  L = 0L, R = 1L, AL = 2L, AN = 3L, EN = 4L, ES = 5L, ET = 6L, CS = 7L,
  NSM = 8L, BN = 9L, B = 10L, S = 11L, WS = 12L, ON = 13L, LRE = 14L,
  LRO = 15L, RLE = 16L, RLO = 17L, PDF = 18L, LRI = 19L, RLI = 20L,
  FSI = 21L, PDI = 22L
)
joining_values <- list(U = 0L, C = 1L, D = 2L, L = 3L, R = 4L, T = 5L)

bidi_ranges <- parse_prop_ranges(
  "DerivedBidiClass.txt", ucd_extracted, bidi_values
)
joining_ranges <- parse_prop_ranges(
  "DerivedJoiningType.txt", ucd_extracted,
  joining_values
)

# ---------------------------------------------------------------------------
# Emit the C++ header and source.
# ---------------------------------------------------------------------------
hexlit <- function(x) sprintf("0x%X", x)
chunk <- function(strs, per = 8L) {
  if (!length(strs)) {
    return("")
  }
  idx <- (seq_along(strs) - 1L) %/% per
  rows <- vapply(
    split(strs, idx), function(g) paste0("  ", toString(g)),
    character(1)
  )
  out <- rows[[1]]
  for (row in rows[-1]) {
    out <- paste0(out, ",\n", row)
  }
  out
}

guard <- "PUNYCODER_UNICODE_TABLES_16_0_0_H"
header <- sprintf("// Generated by generate_unicode_tables.R. DO NOT EDIT.
// Unicode %s. Accessors for NFC + UTS-46 used by canonical-host normalization.
#ifndef %s
#define %s

#include <cstddef>
#include <cstdint>

namespace punycoder {
namespace u16 {

extern const char *const UNICODE_VERSION;

enum class IdnaStatus : uint8_t {
  valid = 0,
  ignored = 1,
  mapped = 2,
  deviation = 3,
  disallowed = 4,
  disallowed_std3_valid = 5,
  disallowed_std3_mapped = 6
};

// Canonical combining class of cp (0 if unlisted).
uint8_t combining_class(uint32_t cp);

// Full canonical decomposition of cp (recursively expanded, excluding Hangul).
// Returns a pointer to len code points, or nullptr with len = 0 if none.
const uint32_t *canonical_decomposition(uint32_t cp, uint32_t &len);

// Primary canonical composition of starter a and combiner b; 0 if none.
uint32_t canonical_compose(uint32_t a, uint32_t b);

// UTS-46 status of cp. If the status is mapped, deviation, or
// disallowed_std3_mapped and a mapping exists, sets map/len to the target
// sequence (len may be 0 for an empty mapping). Unlisted code points are
// disallowed.
IdnaStatus idna_lookup(uint32_t cp, const uint32_t *&map, uint32_t &len);

// True if cp has general category Mn, Mc, or Me (UTS-46 rule V5).
bool is_combining_mark(uint32_t cp);

// Bidi_Class of cp (RFC 5893 CheckBidi). Unlisted code points return L; they
// are disallowed by UTS-46 mapping and never reach CheckBidi.
enum class BidiClass : uint8_t {
  L = 0, R, AL, AN, EN, ES, ET, CS, NSM, BN, B, S, WS, ON,
  LRE, LRO, RLE, RLO, PDF, LRI, RLI, FSI, PDI
};
BidiClass bidi_class(uint32_t cp);

// Joining_Type of cp (IDNA2008 ContextJ CheckJoiners). Unlisted code points
// return U (Non_Joining), the property default.
enum class JoiningType : uint8_t { U = 0, C, D, L, R, T };
JoiningType joining_type(uint32_t cp);

}  // namespace u16
}  // namespace punycoder

#endif  // %s
", unicode_version, guard, guard, guard)

writeLines(header, "src/unicode_tables_16_0_0.h")

# ---- Source ----
# Decomposition flat data + index.
decomp_keys <- as.integer(names(full_decomp))
o <- order(decomp_keys)
decomp_keys <- decomp_keys[o]
decomp_seqs <- full_decomp[o]
flat <- integer(0)
offs <- integer(0)
lens <- integer(0)
for (s in decomp_seqs) {
  offs <- c(offs, length(flat))
  lens <- c(lens, length(s))
  flat <- c(flat, s)
}

src <- c(
  "// Generated by data-raw/generate_unicode_tables.R. DO NOT EDIT BY HAND.",
  sprintf("// Unicode %s.", unicode_version),
  '#include "unicode_tables_16_0_0.h"',
  "",
  "#include <algorithm>",
  "",
  "namespace punycoder {",
  "namespace u16 {",
  "",
  sprintf('const char *const UNICODE_VERSION = "%s";', unicode_version),
  "",
  "namespace {",
  "",
  "// --- Canonical combining class ranges (sorted by lo) ---",
  "struct CccRange { uint32_t lo, hi; uint8_t ccc; };",
  sprintf(
    "const CccRange CCC_RANGES[] = {\n%s\n};",
    chunk(sprintf(
      "{%s, %s, %d}", hexlit(ccc_ranges$lo),
      hexlit(ccc_ranges$hi), ccc_ranges$value
    ), 4L)
  ),
  sprintf("const size_t CCC_N = %d;", nrow(ccc_ranges)),
  "",
  "// --- Combining-mark ranges (Mn/Mc/Me, sorted by lo) ---",
  "struct MarkRange { uint32_t lo, hi; };",
  sprintf(
    "const MarkRange MARK_RANGES[] = {\n%s\n};",
    chunk(
      sprintf("{%s, %s}", hexlit(mark_ranges$lo), hexlit(mark_ranges$hi)), 6L
    )
  ),
  sprintf("const size_t MARK_N = %d;", nrow(mark_ranges)),
  "",
  "// --- Canonical decomposition (index sorted by cp + flat data) ---",
  "struct DecompEntry { uint32_t cp; uint32_t off; uint32_t len; };",
  sprintf(
    "const DecompEntry DECOMP_INDEX[] = {\n%s\n};",
    chunk(sprintf("{%s, %d, %d}", hexlit(decomp_keys), offs, lens), 4L)
  ),
  sprintf("const size_t DECOMP_N = %d;", length(decomp_keys)),
  sprintf("const uint32_t DECOMP_DATA[] = {\n%s\n};", chunk(hexlit(flat), 8L)),
  "",
  "// --- Canonical composition pairs (sorted by a, then b) ---",
  "struct CompEntry { uint32_t a, b, c; };",
  sprintf(
    "const CompEntry COMP_TABLE[] = {\n%s\n};",
    chunk(
      sprintf(
        "{%s, %s, %s}", hexlit(comp_a), hexlit(comp_b), hexlit(comp_c)
      ),
      3L
    )
  ),
  sprintf("const size_t COMP_N = %d;", length(comp_a)),
  "",
  "// --- UTS-46 mapping table (ranges sorted by lo + flat mapping data) ---",
  "struct IdnaRange { uint32_t lo, hi; uint8_t status; uint32_t off, len; };"
)

# IDNA flat mapping data + ranges.
idna_flat <- integer(0)
idna_off <- integer(0)
idna_len <- integer(0)
for (m in idna_map) {
  idna_off <- c(idna_off, length(idna_flat))
  idna_len <- c(idna_len, length(m))
  idna_flat <- c(idna_flat, m)
}
src <- c(
  src,
  sprintf(
    "const IdnaRange IDNA_RANGES[] = {\n%s\n};",
    chunk(sprintf(
      "{%s, %s, %d, %d, %d}", hexlit(idna_lo), hexlit(idna_hi),
      idna_status, idna_off, idna_len
    ), 3L)
  ),
  sprintf("const size_t IDNA_N = %d;", length(idna_lo)),
  if (length(idna_flat)) {
    sprintf(
      "const uint32_t IDNA_MAP_DATA[] = {\n%s\n};",
      chunk(hexlit(idna_flat), 8L)
    )
  } else {
    "const uint32_t IDNA_MAP_DATA[] = {0};"
  },
  "",
  "// --- Bidi_Class ranges (RFC 5893, sorted by lo) ---",
  "struct BidiRange { uint32_t lo, hi; uint8_t value; };",
  sprintf(
    "const BidiRange BIDI_RANGES[] = {\n%s\n};",
    chunk(sprintf(
      "{%s, %s, %d}", hexlit(bidi_ranges$lo),
      hexlit(bidi_ranges$hi), bidi_ranges$value
    ), 4L)
  ),
  sprintf("const size_t BIDI_N = %d;", nrow(bidi_ranges)),
  "",
  "// --- Joining_Type ranges (IDNA2008 ContextJ, sorted by lo) ---",
  "struct JoiningRange { uint32_t lo, hi; uint8_t value; };",
  sprintf(
    "const JoiningRange JOINING_RANGES[] = {\n%s\n};",
    chunk(sprintf(
      "{%s, %s, %d}", hexlit(joining_ranges$lo),
      hexlit(joining_ranges$hi), joining_ranges$value
    ), 4L)
  ),
  sprintf("const size_t JOINING_N = %d;", nrow(joining_ranges)),
  "",
  "}  // namespace",
  "",
  "uint8_t combining_class(uint32_t cp) {",
  "  size_t lo = 0, hi = CCC_N;",
  "  while (lo < hi) {",
  "    size_t mid = (lo + hi) / 2;",
  "    if (cp < CCC_RANGES[mid].lo) hi = mid;",
  "    else if (cp > CCC_RANGES[mid].hi) lo = mid + 1;",
  "    else return CCC_RANGES[mid].ccc;",
  "  }",
  "  return 0;",
  "}",
  "",
  "bool is_combining_mark(uint32_t cp) {",
  "  size_t lo = 0, hi = MARK_N;",
  "  while (lo < hi) {",
  "    size_t mid = (lo + hi) / 2;",
  "    if (cp < MARK_RANGES[mid].lo) hi = mid;",
  "    else if (cp > MARK_RANGES[mid].hi) lo = mid + 1;",
  "    else return true;",
  "  }",
  "  return false;",
  "}",
  "",
  "const uint32_t *canonical_decomposition(uint32_t cp, uint32_t &len) {",
  "  size_t lo = 0, hi = DECOMP_N;",
  "  while (lo < hi) {",
  "    size_t mid = (lo + hi) / 2;",
  "    if (cp < DECOMP_INDEX[mid].cp) hi = mid;",
  "    else if (cp > DECOMP_INDEX[mid].cp) lo = mid + 1;",
  "    else {",
  "      len = DECOMP_INDEX[mid].len;",
  "      return &DECOMP_DATA[DECOMP_INDEX[mid].off];",
  "    }",
  "  }",
  "  len = 0;",
  "  return nullptr;",
  "}",
  "",
  "uint32_t canonical_compose(uint32_t a, uint32_t b) {",
  "  size_t lo = 0, hi = COMP_N;",
  "  while (lo < hi) {",
  "    size_t mid = (lo + hi) / 2;",
  "    const CompEntry &e = COMP_TABLE[mid];",
  "    if (a < e.a || (a == e.a && b < e.b)) hi = mid;",
  "    else if (a > e.a || (a == e.a && b > e.b)) lo = mid + 1;",
  "    else return e.c;",
  "  }",
  "  return 0;",
  "}",
  "",
  "IdnaStatus idna_lookup(uint32_t cp, const uint32_t *&map, uint32_t &len) {",
  "  size_t lo = 0, hi = IDNA_N;",
  "  while (lo < hi) {",
  "    size_t mid = (lo + hi) / 2;",
  "    const IdnaRange &r = IDNA_RANGES[mid];",
  "    if (cp < r.lo) hi = mid;",
  "    else if (cp > r.hi) lo = mid + 1;",
  "    else {",
  "      len = r.len;",
  "      map = r.len ? &IDNA_MAP_DATA[r.off] : nullptr;",
  "      return static_cast<IdnaStatus>(r.status);",
  "    }",
  "  }",
  "  map = nullptr;",
  "  len = 0;",
  "  return IdnaStatus::disallowed;",
  "}",
  "",
  "BidiClass bidi_class(uint32_t cp) {",
  "  size_t lo = 0, hi = BIDI_N;",
  "  while (lo < hi) {",
  "    size_t mid = (lo + hi) / 2;",
  "    if (cp < BIDI_RANGES[mid].lo) hi = mid;",
  "    else if (cp > BIDI_RANGES[mid].hi) lo = mid + 1;",
  "    else return static_cast<BidiClass>(BIDI_RANGES[mid].value);",
  "  }",
  "  return BidiClass::L;",
  "}",
  "",
  "JoiningType joining_type(uint32_t cp) {",
  "  size_t lo = 0, hi = JOINING_N;",
  "  while (lo < hi) {",
  "    size_t mid = (lo + hi) / 2;",
  "    if (cp < JOINING_RANGES[mid].lo) hi = mid;",
  "    else if (cp > JOINING_RANGES[mid].hi) lo = mid + 1;",
  "    else return static_cast<JoiningType>(JOINING_RANGES[mid].value);",
  "  }",
  "  return JoiningType::U;",
  "}",
  "",
  "}  // namespace u16",
  "}  // namespace punycoder"
)

writeLines(src, "src/unicode_tables_16_0_0.cpp")

message(sprintf(
  paste0(
    "generated src/unicode_tables_16_0_0.{h,cpp}: ccc=%d ranges, ",
    "marks=%d ranges, decomp=%d, comp=%d pairs, idna=%d ranges ",
    "(map data %d), bidi=%d ranges, joining=%d ranges"
  ),
  nrow(ccc_ranges), nrow(mark_ranges), length(decomp_keys), length(comp_a),
  length(idna_lo), length(idna_flat), nrow(bidi_ranges), nrow(joining_ranges)
))
