#!/usr/bin/env Rscript
#
# Generate the vendored Unicode data tables that punycoder's in-tree
# canonical-host normalization depends on (NFC + UTS-46), pinned to one Unicode
# version. See dev/normalization-contract.md (section 0, decision 3).
#
# Run from the package root:  Rscript data-raw/generate_unicode_tables.R
#
# Network access happens HERE, at generation time only. The generated C++
# (src/unicode_tables_<version>.{h,cpp}) is committed; the package never
# downloads anything at build or run time. Downloaded UCD files are cached under
# data-raw/.ucd-cache/<version>/ (git-ignored) -- keyed by version, because the
# file NAMES are identical across versions and a flat cache would silently serve
# one version's UnicodeData.txt to another version's run.
#
# This pass emits the tables needed by NFC (PSLR-pzeeruwe), UTS-46 mapping +
# label validation (PSLR-pwwtqowh), and the CheckBidi/CheckJoiners label rules
# (PSLR-izaqpicn): canonical combining class, canonical decomposition
# (recursively expanded), canonical composition, the UTS-46 mapping/status
# table, the combining-mark set (for the V5 "label must not begin with a
# combining mark" rule), and the Bidi_Class + Joining_Type properties (for
# RFC 5893 CheckBidi and IDNA2008 ContextJ CheckJoiners).

unicode_version <- "16.0.0"

# Everything the emitted C++ is NAMED after is derived from that one string, in
# the same derived-not-hand-written spirit as ADR-011/ADR-012: a version bump is
# this line and nothing else, and two versions can be emitted side by side
# without colliding.
version_tag <- gsub(".", "_", unicode_version, fixed = TRUE)  # 16.0.0 -> 16_0_0
version_major <- sub("\\..*$", "", unicode_version)           # 16.0.0 -> 16
table_stem <- sprintf("unicode_tables_%s", version_tag)
table_ns <- sprintf("u%s", version_major)
guard <- sprintf("PUNYCODER_%s_H", toupper(table_stem))

ucd_base <- sprintf("https://www.unicode.org/Public/%s/ucd", unicode_version)

# The IDNA directory MOVED in Unicode 17: Public/idna/<ver> became
# Public/<ver>/idna. Both layouts are tried, newest-first, so this generator can
# still produce a <=16.0.0 table set. Deliberately NOT Public/idna/latest/ --
# which is byte-identical to the current release but would defeat the entire
# point of vendoring a pinned version.
idna_bases <- c(
  sprintf("https://www.unicode.org/Public/%s/idna", unicode_version),
  sprintf("https://www.unicode.org/Public/idna/%s", unicode_version)
)

cache_dir <- file.path("data-raw", ".ucd-cache", unicode_version)
dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

fetch <- function(name, base) {
  dest <- file.path(cache_dir, name)
  if (!file.exists(dest)) {
    ok <- FALSE
    for (b in base) {
      url <- sprintf("%s/%s", b, name)
      message("downloading ", url)
      ok <- tryCatch({
        utils::download.file(url, dest, mode = "wb", quiet = TRUE)
        TRUE
      }, error = function(e) {
        message("  failed: ", conditionMessage(e))
        FALSE
      })
      if (ok) break
      unlink(dest)
    }
    if (!ok) {
      stop(sprintf("could not fetch %s from any of: %s", name, toString(base)))
    }
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
# DerivedNormalizationProps.txt, read for two properties.
#
# Full_Composition_Exclusion: a primary canonical decomposition of length 2
# yields a composition pair UNLESS the composite is fully-composition-excluded.
#
# NFC_Quick_Check: the UAX #15 "Detecting Normalization Forms" property, used
# to skip the whole decompose/reorder/compose pipeline for input that is
# already in NFC. Only No and Maybe are listed; Yes is the default, and is by
# far the common case. MAYBE IS A REAL THIRD VALUE -- a character that may
# compose with what precedes it -- and must fall through to the full pipeline
# rather than being folded into Yes.
# ---------------------------------------------------------------------------
dnp <- strip_comment(fetch("DerivedNormalizationProps.txt", ucd_base))
dnp <- dnp[nzchar(dnp)]
fce <- new.env(parent = emptyenv())
qc_lo <- integer(0)
qc_hi <- integer(0)
qc_val <- integer(0)
# Codes must match the C++ NfcQuickCheck enum emitted below.
qc_codes <- c(N = 1L, M = 2L)
for (line in dnp) {
  segs <- trimws(strsplit(line, ";", fixed = TRUE)[[1]])
  if (length(segs) < 2L) next
  if (segs[[2]] != "Full_Composition_Exclusion" && segs[[2]] != "NFC_QC") next
  rng <- strsplit(segs[[1]], "..", fixed = TRUE)[[1]]
  lo <- hex(rng[[1]])
  hi <- if (length(rng) > 1L) hex(rng[[2]]) else lo
  if (segs[[2]] == "Full_Composition_Exclusion") {
    for (cp in lo:hi) assign(as.character(cp), TRUE, envir = fce)
    next
  }
  code <- qc_codes[[segs[[3]]]]
  if (is.null(code)) stop("unmapped NFC_QC value: ", segs[[3]])
  qc_lo <- c(qc_lo, lo)
  qc_hi <- c(qc_hi, hi)
  qc_val <- c(qc_val, code)
}
if (!length(qc_lo)) stop("no NFC_QC rows found in DerivedNormalizationProps")

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
idna <- strip_comment(fetch("IdnaMappingTable.txt", idna_bases))
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

max_cp <- 0x10FFFFL
n_cp <- max_cp + 1L

covers_ascii <- function(lo) min(lo) < 0x80L

# ---------------------------------------------------------------------------
# Flat payload arrays.
#
# Both the decomposition sequences and the UTS-46 mapping targets are stored as
# one flat array plus (offset, length) pairs, so a lookup returns a pointer
# into shared storage rather than copying. Built here rather than at emission
# time because the offsets are part of what the UTS-46 value table below
# deduplicates on.
# ---------------------------------------------------------------------------
decomp_keys <- sort(as.integer(names(full_decomp)))
decomp_seqs <- full_decomp[order(as.integer(names(full_decomp)))]
decomp_data <- unlist(decomp_seqs, use.names = FALSE)
decomp_len <- vapply(decomp_seqs, length, integer(1))
decomp_off <- cumsum(decomp_len) - decomp_len

idna_data <- unlist(idna_map, use.names = FALSE)
idna_len <- vapply(idna_map, length, integer(1))
idna_off <- cumsum(idna_len) - idna_len

# ---------------------------------------------------------------------------
# Lookup shapes.
#
# PUNY-zgaqusnu made ASCII free: the two tables covering ASCII got a 128-entry
# direct index and the rest a bounds test against their own first listed code
# point. What it left on the table is that every NON-ASCII code point still
# pays ~11-14 data-dependent, branch-mispredicting probes -- and the worst case
# is not an exotic character but a common one the table does not list. Every
# CJK ideograph walks the whole combining-class table only to conclude 0.
#
# So the tables that profile hot get a two-stage trie: one block-index read
# plus one value read, O(1) for EVERY code point, ASCII included. The trie
# SUBSUMES the 128-entry ASCII array rather than sitting beside it.
# Deduplicating identical blocks is what makes it affordable -- the unassigned
# gaps, which are most of the code space, all collapse onto one shared block.
#
# The one piece of PUNY-zgaqusnu that survives in front of a trie is the low
# bound, where the table has one: two loads are cheap, but zero loads are
# cheaper, and a table listing nothing below U+0300 can still answer every
# ASCII character from a compare. Dropping it cost 3% on all-ASCII input,
# which is the dominant case in real host data. See trie_guard() below.
#
# WHICH tables is measured, not assumed. Self time in host_normalize over an
# all-non-ASCII corpus, after PUNY-zgaqusnu: combining_class 10.3%,
# idna_lookup 5.7%, canonical_decomposition 5.7%, bidi_class 5.6%,
# canonical_compose 4.1%, is_combining_mark 1.7%, joining_type below the
# sampling floor. The first four are converted here. is_combining_mark and
# joining_type keep their bounds test and their search: both are consulted once
# per LABEL, not once per code point, so a trie would add 15-20 KB of
# permanently cold table to shorten a search that barely registers.
#
# canonical_compose is keyed on a PAIR of code points, so it cannot be a trie
# the way the four above are -- but it can be a trie on ONE element of the pair
# with a short scan behind it, which is what it now is (PUNY-mbzhgbta, below).
# ---------------------------------------------------------------------------

# One value per code point in [0, max_cp], expanded from [lo, hi] = value rows.
value_space <- function(lo, hi, value, default) {
  v <- rep(default, n_cp)
  for (i in seq_along(lo)) v[(lo[i]:hi[i]) + 1L] <- value[i]
  v
}

# Narrowest unsigned C type that holds every value in x. Derived rather than
# hand-picked so a version bump that outgrows a width widens the emitted type
# instead of silently truncating (ADR-011).
elem_type <- function(x) {
  m <- max(x)
  if (m <= 255L) {
    "uint8_t"
  } else if (m <= 65535L) {
    "uint16_t"
  } else {
    "uint32_t"
  }
}

elem_bytes <- function(x) {
  c(uint8_t = 1L, uint16_t = 2L, uint32_t = 4L)[[elem_type(x)]]
}

# Build the two-stage trie for a per-code-point value vector.
#
# Stage 1 maps cp >> SHIFT to a block number; stage 2 stores the blocks, with
# identical blocks written once. Lookup is two loads and no branches:
#   STAGE2[(STAGE1[cp >> SHIFT] << SHIFT) | (cp & MASK)]
#
# Stage 1 holds the block NUMBER rather than a byte offset into stage 2. That
# is what keeps it in uint8_t for three of the four tables, and stage 1 is the
# array every lookup touches, so its width matters more than the shift the
# runtime pays to undo the encoding.
#
# The block size is not fixed either: the trie is built at every shift and the
# smallest wins, ties going to the larger block (whose stage 1 is smaller). A
# Unicode version bump re-runs that choice on its own.
build_trie <- function(name, values, default) {
  used <- which(values != default)
  last_used <- if (length(used)) max(used) - 1L else 0L
  first_used <- if (length(used)) min(used) - 1L else 0L

  best <- NULL
  for (shift in 4:10) {
    block <- bitwShiftL(1L, shift)
    limit <- min(((last_used %/% block) + 1L) * block, n_cp)
    m <- matrix(values[seq_len(limit)], nrow = block)
    key <- do.call(paste, c(as.data.frame(t(m)), sep = "\r"))
    keep <- !duplicated(key)
    stage1 <- match(key, key[keep]) - 1L
    stage2 <- as.vector(m[, keep, drop = FALSE])
    bytes <- length(stage1) * elem_bytes(stage1) +
      length(stage2) * elem_bytes(stage2)
    if (is.null(best) || bytes <= best$bytes) {
      best <- list(
        name = name, shift = shift, block = block, limit = limit,
        first = first_used, last = limit - 1L, stage1 = stage1,
        stage2 = stage2, bytes = bytes
      )
    }
  }

  # ADR-011, taken to its conclusion: the emitted structure is checked against
  # the vector it was derived from for every one of the 1,114,112 code points,
  # not just the ones a conformance corpus happens to reach. A trie that
  # disagreed with its source ranges anywhere stops the generator here.
  #
  # What is replayed is the ACCESSOR, guards included -- outside
  # [first, last] the emitted code returns the default without touching the
  # trie, so the check has to do the same or it would not be checking the code
  # that ships.
  cps <- (best$first:best$last)
  got <- rep(default, n_cp)
  got[cps + 1L] <- best$stage2[
    bitwShiftL(best$stage1[bitwShiftR(cps, best$shift) + 1L], best$shift) +
      bitwAnd(cps, best$block - 1L) + 1L
  ]
  if (!identical(got, values)) {
    stop(sprintf("the %s trie disagrees with its source ranges", name))
  }
  best
}

ccc_trie <- build_trie(
  "combining class",
  value_space(ccc_ranges$lo, ccc_ranges$hi, ccc_ranges$value, 0L), 0L
)

bidi_trie <- build_trie(
  "Bidi_Class",
  value_space(bidi_ranges$lo, bidi_ranges$hi, bidi_ranges$value, 0L), 0L
)

# Decomposition: the trie stores a 1-BASED index into DECOMP_INDEX so that 0
# means "no decomposition" without a parallel presence table.
decomp_space <- rep(0L, n_cp)
decomp_space[decomp_keys + 1L] <- seq_along(decomp_keys)
decomp_trie <- build_trie("canonical decomposition", decomp_space, 0L)

# UTS-46: the trie stores an index into a table of DISTINCT (status, mapping)
# values rather than one per range. Ranges carrying no mapping differ only in
# status, so the thousands of disallowed unassigned ranges collapse onto a
# single value -- which is also what lets their trie blocks deduplicate. With
# the value id in hand the range table itself is dead, and dropping it is why
# this change makes the shared object smaller rather than larger.
#
# The trailing synthetic entry is the value an UNLISTED code point takes
# (disallowed, no mapping). This table happens to cover the whole code space,
# but the default is derived rather than assumed so it stays correct if a
# future version leaves a hole.
idna_key <- c(
  ifelse(
    idna_len > 0L,
    sprintf("%d:%d:%d", idna_status, idna_off, idna_len),
    sprintf("%d:-", idna_status)
  ),
  sprintf("%d:-", status_code[["disallowed"]])
)
idna_uniq <- !duplicated(idna_key)
idna_value_status <- c(idna_status, status_code[["disallowed"]])[idna_uniq]
idna_value_off <- c(ifelse(idna_len > 0L, idna_off, 0L), 0L)[idna_uniq]
idna_value_len <- c(idna_len, 0L)[idna_uniq]
idna_value_of <- match(idna_key, idna_key[idna_uniq]) - 1L
idna_default <- idna_value_of[[length(idna_value_of)]]

idna_trie <- build_trie(
  "UTS-46 mapping",
  value_space(
    idna_lo, idna_hi, idna_value_of[seq_along(idna_lo)], idna_default
  ),
  idna_default
)

# The two tables that still binary-search, and so still need the bounds test to
# answer ASCII for them. A derived bound stays CORRECT no matter what the data
# does -- what a version bump could break is the shape choice: if one of these
# grew down into ASCII, its guard would quietly stop firing and ASCII would
# fall back into the search, a silent performance regression with no wrong
# answer to reveal it. Assert the shape so that bump fails loudly here instead.
bounds_tested <- list(
  mark = mark_ranges$lo,
  joining = joining_ranges$lo
)
for (nm in names(bounds_tested)) {
  lo <- bounds_tested[[nm]]
  if (covers_ascii(lo)) {
    stop(sprintf(
      paste0(
        "the %s table now reaches ASCII (first = U+%04X), so its bounds test ",
        "no longer answers ASCII; give it a 128-entry direct index like ",
        "idna/bidi instead"
      ), nm, min(lo)
    ))
  }
}

# Composition: the decomposition shape run backwards. A trie on ONE element of
# the pair maps it to a run of partners to scan, so the pair lookup becomes the
# same two loads plus a short walk that canonical_decomposition already is.
#
# WHICH element is measured off the data rather than picked. The 961 pairs hold
# 391 distinct a but only 72 distinct b, so keying on a leaves runs with a
# median of 1 and a maximum of 19, where keying on b would leave 3 and 117.
# Keying on a also puts the REJECT on the trie, which is where the time
# actually went: a starter that never composes -- every CJK ideograph, every
# Hangul syllable, every unaccented letter -- used to walk the whole 961-pair
# search only to conclude 0, and now costs two loads.
comp_rle <- rle(comp_a)
comp_keys <- comp_rle$values
comp_run <- comp_rle$lengths
comp_off <- cumsum(comp_run) - comp_run

comp_space <- rep(0L, n_cp)
comp_space[comp_keys + 1L] <- seq_along(comp_keys)
comp_trie <- build_trie("canonical composition", comp_space, 0L)

# build_trie() has already proved the a -> run mapping over all 1,114,112 code
# points. What remains of the accessor is the scan, so check what the scan
# assumes: that each run holds exactly the pairs recorded for its own a, in
# strictly ascending b. Those two together are the whole accessor -- a b that
# is not in the run cannot match anything in it, so the b-bound in front is an
# optimization and not part of the contract.
for (i in seq_along(comp_keys)) {
  idx <- comp_off[i] + seq_len(comp_run[i])
  if (!all(comp_a[idx] == comp_keys[i]) ||
    is.unsorted(comp_b[idx], strictly = TRUE)) {
    stop(sprintf(
      "the canonical composition run for U+%04X is not a sorted partition",
      comp_keys[i]
    ))
  }
}

# The second element of a composition pair is always a combining character, so
# a bound on b alone keeps ASCII text out of the structure entirely -- with no
# memory access at all, which still beats the trie's two loads. (A bound on a
# would not: the smallest a is U+003C.) Same reasoning as the bounds-tested
# tables above: the bound is derived and cannot go wrong, only stop paying off,
# so assert the shape it assumes.
comp_b_first <- min(comp_b)
comp_b_last <- max(comp_b)
if (covers_ascii(comp_b)) {
  stop(sprintf(
    paste0(
      "a composition pair now has an ASCII second element (U+%04X), so the ",
      "b-bound in canonical_compose() no longer keeps ASCII out of the lookup"
    ), comp_b_first
  ))
}

# NFC_Quick_Check: the same trie shape, so the per-character check the quick
# check runs is two loads rather than a search. Yes is the default and covers
# almost the whole code space, which is exactly the case block dedup collapses.
qc_trie <- build_trie(
  "NFC_Quick_Check", value_space(qc_lo, qc_hi, qc_val, 0L), 0L
)

# The bound in front of the whole quick check. A code point below BOTH tables'
# first listed entry has combining class 0 and NFC_Quick_Check=Yes, so it can
# neither be out of canonical order nor fail the check: a run of them is
# already in NFC, at one compare each and no memory access. That is the whole
# ASCII case, which is why this bound rather than the two accessors' own guards
# is what the check tests first -- their guards are behind a function call, and
# this one is inlined at the call site (the PUNY-mbzhgbta lesson).
nfc_inert_limit <- min(min(qc_lo), min(ccc_ranges$lo))
if (nfc_inert_limit <= 0x7FL) {
  stop(sprintf(
    paste0(
      "a code point at U+%04X now has nonzero combining class or ",
      "NFC_QC != Yes, so nfc_inert() no longer answers ASCII and the quick ",
      "check would fall into the tables for ordinary host input"
    ), nfc_inert_limit
  ))
}

# Every second element of a composition pair can combine with what precedes it,
# so NFC_QC must not call it Yes. This cross-checks the parsed property against
# the pair table derived independently from UnicodeData -- a mis-parsed NFC_QC
# would otherwise be silent on almost every input, and wrong on exactly the
# input the quick check exists to skip.
qc_of <- function(cp) {
  hit <- which(qc_lo <= cp & cp <= qc_hi)
  if (length(hit)) qc_val[[hit[[1]]]] else 0L
}
bad_b <- unique(comp_b)[vapply(unique(comp_b), qc_of, integer(1)) == 0L]
if (length(bad_b)) {
  stop(sprintf(
    "U+%04X is the second element of a composition pair but NFC_QC says Yes",
    bad_b[[1]]
  ))
}

# ---------------------------------------------------------------------------
# Emit the C++ header and source.
# ---------------------------------------------------------------------------
hexlit <- function(x) sprintf("0x%X", x)

# The derived [first, last] bounds of a table, and the guard expression that
# uses them. A half whose bound is the edge of the code space is dropped from
# both: an always-false test would be dead code in the generated file.
has_lo_guard <- function(lo) min(lo) > 0L
has_hi_guard <- function(hi) max(hi) < max_cp

bounds_const <- function(prefix, lo, hi) {
  parts <- character(0)
  if (has_lo_guard(lo)) {
    parts <- c(parts, sprintf("%s_FIRST = %s", prefix, hexlit(min(lo))))
  }
  if (has_hi_guard(hi)) {
    parts <- c(parts, sprintf("%s_LAST = %s", prefix, hexlit(max(hi))))
  }
  if (!length(parts)) {
    return(character(0))
  }
  sprintf("const uint32_t %s;", toString(parts))
}

guard_expr <- function(prefix, lo, hi) {
  parts <- character(0)
  if (has_lo_guard(lo)) parts <- c(parts, sprintf("cp < %s_FIRST", prefix))
  if (has_hi_guard(hi)) parts <- c(parts, sprintf("cp > %s_LAST", prefix))
  paste(parts, collapse = " || ")
}
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

# Literals per row that keeps an emitted array inside 80 columns. Derived from
# the widest literal in the array, so a table whose values grow reflows instead
# of overflowing.
per_line <- function(strs) {
  max(1L, 78L %/% (max(nchar(strs)) + 2L))
}

# A trie as C++: the two arrays plus the three constants the accessor needs.
# Every one of them comes out of build_trie(), including the element types.
emit_trie <- function(prefix, trie) {
  s1 <- sprintf("%d", trie$stage1)
  s2 <- sprintf("%d", trie$stage2)
  c(
    sprintf(
      "const %s %s1[] = {\n%s\n};", elem_type(trie$stage1), prefix,
      chunk(s1, per_line(s1))
    ),
    sprintf(
      "const %s %s2[] = {\n%s\n};", elem_type(trie$stage2), prefix,
      chunk(s2, per_line(s2))
    ),
    sprintf(
      "const uint32_t %s_SHIFT = %d, %s_LAST = %s;",
      prefix, trie$shift, prefix, hexlit(trie$last)
    ),
    if (trie$first > 0L) {
      sprintf("const uint32_t %s_FIRST = %s;", prefix, hexlit(trie$first))
    } else {
      character(0)
    }
  )
}

# The guard in front of a trie lookup.
#
# The LAST half is not an optimization and is emitted even where LAST is
# U+10FFFF: a trie is indexed directly by cp, uint32_t can hold a value past
# the end of the code space, and the array would be read out of range.
#
# The FIRST half IS an optimization, and is the one part of PUNY-zgaqusnu's
# bounds test worth keeping in front of a trie. Where a table lists nothing
# below its first code point -- U+0300 for combining class, U+00C0 for
# decomposition -- that compare answers all of ASCII with NO memory access at
# all, which still beats the trie's two loads. Tables that cover ASCII (UTS-46
# mapping, Bidi_Class) have no such bound and go straight to the trie, which is
# what lets it subsume their 128-entry ASCII arrays.
#
# `var` is the accessor's parameter name: every trie but the composition one is
# keyed on the code point `cp`, and that one is keyed on the first element `a`.
trie_guard <- function(prefix, trie, var = "cp") {
  parts <- sprintf("%s > %s_LAST", var, prefix)
  if (trie$first > 0L) {
    parts <- c(sprintf("%s < %s_FIRST", var, prefix), parts)
  }
  paste(parts, collapse = " || ")
}

# The same test the other way round, for the accessors that read better as
# "in range -> look it up" than as an early return.
trie_in_range <- function(prefix, trie, var = "cp") {
  parts <- sprintf("%s <= %s_LAST", var, prefix)
  if (trie$first > 0L) {
    parts <- c(sprintf("%s >= %s_FIRST", var, prefix), parts)
  }
  paste(parts, collapse = " && ")
}

# The trie lookup as it appears inside an accessor body.
trie_call <- function(prefix, var = "cp") {
  sprintf("trie_lookup(%s2, %s1, %s_SHIFT, %s)", prefix, prefix, prefix, var)
}

header <- sprintf(
  "// Generated by data-raw/generate_unicode_tables.R. DO NOT EDIT BY HAND.
// Unicode %s. Accessors for NFC + UTS-46 used by canonical-host normalization.
#ifndef %s
#define %s

#include <cstddef>
#include <cstdint>

namespace punycoder {
namespace %s {

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

// True if b can be the SECOND element of some canonical composition pair.
// This is the bound canonical_compose() applies before anything else, exposed
// here so a caller can apply it BEFORE the call rather than after: b is always
// a combining character, so ordinary text answers it without touching memory,
// and at that point the call itself is the whole cost. Both bounds are derived
// from the pair table like every other constant in this file (ADR-011).
inline bool composes_as_second(uint32_t b) {
  return b >= %s && b <= %s;
}

// NFC_Quick_Check (UAX #15). `maybe` means the character MAY compose with
// what precedes it, so it is not a weaker `no` -- a caller that folds it into
// `yes` is wrong on exactly the input a quick check exists to detect.
enum class NfcQuickCheck : uint8_t { yes = 0, no = 1, maybe = 2 };
NfcQuickCheck nfc_quick_check(uint32_t cp);

// True if cp can play no part in whether a sequence is in NFC: every code
// point below this bound has combining class 0 and NFC_Quick_Check=Yes, so a
// run of them is already normalized. Inline because the check that uses it
// runs once per character and this answers all of ASCII without a call, let
// alone a table read. The bound is the lower of the two tables' first listed
// code point, derived like every other constant here (ADR-011).
inline bool nfc_inert(uint32_t cp) { return cp < %s; }

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

}  // namespace %s
}  // namespace punycoder

#endif  // %s
", unicode_version, guard, guard, table_ns, hexlit(comp_b_first),
  hexlit(comp_b_last), hexlit(nfc_inert_limit), table_ns, guard
)

writeLines(header, sprintf("src/%s.h", table_stem))

# ---- Source ----
src <- c(
  "// Generated by data-raw/generate_unicode_tables.R. DO NOT EDIT BY HAND.",
  sprintf("// Unicode %s.", unicode_version),
  sprintf('#include "%s.h"', table_stem),
  "",
  "namespace punycoder {",
  sprintf("namespace %s {", table_ns),
  "",
  sprintf('const char *const UNICODE_VERSION = "%s";', unicode_version),
  "",
  "namespace {",
  "",
  "// Two-stage trie: one block-index read plus one value read, O(1) for every",
  "// code point. Stage 1 maps cp >> SHIFT to a block NUMBER -- not a byte",
  "// offset, which is what keeps stage 1 in uint8_t for most tables; stage 1",
  "// is touched by every lookup, so its width matters more than the shift the",
  "// CPU pays to undo the encoding. Identical blocks are stored once, which",
  "// is what keeps the whole structure affordable: the unassigned gaps, most",
  "// of the code space, share a single block.",
  "template <typename Value, typename Index>",
  "inline Value trie_lookup(const Value *values, const Index *index,",
  "                         uint32_t shift, uint32_t cp) {",
  "  const uint32_t block = index[cp >> shift];",
  "  return values[(block << shift) | (cp & ((1u << shift) - 1))];",
  "}",
  "",
  "// One binary search over a sorted, non-overlapping [lo, hi] range table,",
  "// shared by the two properties that kept a search. The accessors differ",
  "// only in the table searched and the value an unlisted code point falls",
  "// back to.",
  "template <typename Range>",
  "inline const Range *range_lookup(const Range *ranges, size_t n,",
  "                                 uint32_t cp) {",
  "  size_t lo = 0, hi = n;",
  "  while (lo < hi) {",
  "    const size_t mid = (lo + hi) / 2;",
  "    if (cp < ranges[mid].lo) hi = mid;",
  "    else if (cp > ranges[mid].hi) lo = mid + 1;",
  "    else return &ranges[mid];",
  "  }",
  "  return nullptr;",
  "}",
  "",
  "// A trie is indexed directly by cp, so every trie accessor first bounds cp",
  "// against its own derived LAST. That test is not an optimization and must",
  "// not be dropped even where LAST is U+10FFFF: uint32_t can hold a value",
  "// past the end of the code space, and the table would be read out of",
  "// range. The FIRST half, where a table has one, IS an optimization: it",
  "// answers all of ASCII with no memory access at all, which still beats the",
  "// trie's two loads.",
  "",
  "// --- Canonical combining class (two-stage trie) ---",
  emit_trie("CCC_TRIE", ccc_trie),
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
  bounds_const("MARK", mark_ranges$lo, mark_ranges$hi),
  "",
  "// --- Canonical decomposition (two-stage trie + flat data) ---",
  "// The trie stores a 1-BASED index into DECOMP_INDEX, so 0 means \"no",
  "// decomposition\" and no separate presence test is needed. The key the old",
  "// index carried is gone: the trie answers where each entry belongs.",
  sprintf(
    "struct DecompEntry { %s off; %s len; };",
    elem_type(decomp_off), elem_type(decomp_len)
  ),
  sprintf(
    "const DecompEntry DECOMP_INDEX[] = {\n%s\n};",
    chunk(sprintf("{%d, %d}", decomp_off, decomp_len), 8L)
  ),
  sprintf(
    "const uint32_t DECOMP_DATA[] = {\n%s\n};", chunk(hexlit(decomp_data), 8L)
  ),
  emit_trie("DECOMP_TRIE", decomp_trie),
  "",
  "// --- Canonical composition (two-stage trie on the FIRST element) ---",
  "// A pair key cannot be a trie the way the tables above are, but ONE",
  "// element of it can: this is the decomposition shape run backwards. The",
  "// trie maps the starter a to a 1-BASED index into COMP_INDEX (0 = a never",
  "// composes), which delimits the run of (b, c) pairs in COMP_DATA to scan.",
  "//",
  "// Keying on a rather than b is measured off the data, not picked: 961",
  "// pairs hold 391 distinct a but only 72 distinct b, so a-runs are a median",
  "// of 1 and a maximum of 19 long where b-runs would be 3 and 117. It also",
  "// puts the reject on the trie, which is where the time went -- a starter",
  "// that never composes is two loads, not a walk over all 961 pairs.",
  sprintf(
    "struct CompIndex { %s off; %s len; };",
    elem_type(comp_off), elem_type(comp_run)
  ),
  sprintf(
    "const CompIndex COMP_INDEX[] = {\n%s\n};",
    chunk(sprintf("{%d, %d}", comp_off, comp_run), 8L)
  ),
  "// Each run is sorted by b, so the scan stops early on a miss -- and the",
  "// common Latin accents (U+0300..U+030C) sort first in every run that has",
  "// them, so a hit on one is found in the first iteration or two.",
  "struct CompPair { uint32_t b, c; };",
  sprintf(
    "const CompPair COMP_DATA[] = {\n%s\n};",
    chunk(sprintf("{%s, %s}", hexlit(comp_b), hexlit(comp_c)), 4L)
  ),
  emit_trie("COMP_TRIE", comp_trie),
  "// Bounds of the SECOND element only: b is always a combining character,",
  "// while a can be ASCII (the smallest is U+003C), so only a b-bound keeps",
  "// ASCII text out of the lookup -- and it does so with no memory access at",
  "// all, which still beats the trie's two loads.",
  sprintf(
    "const uint32_t COMP_B_FIRST = %s, COMP_B_LAST = %s;",
    hexlit(comp_b_first), hexlit(comp_b_last)
  ),
  "",
  "// --- UTS-46 mapping (two-stage trie + distinct values + flat data) ---",
  "// The trie stores an index into IDNA_VALUES, not into a range table: every",
  "// range that carries no mapping differs only in status, so the thousands",
  "// of disallowed unassigned ranges share ONE value here, and their blocks",
  "// deduplicate with each other as a result. That is why this structure is",
  "// smaller than the range table it replaced, not larger.",
  sprintf(
    "struct IdnaValue { %s off; uint8_t status; %s len; };",
    elem_type(idna_value_off), elem_type(idna_value_len)
  ),
  sprintf(
    "const IdnaValue IDNA_VALUES[] = {\n%s\n};",
    chunk(sprintf(
      "{%d, %d, %d}", idna_value_off, idna_value_status, idna_value_len
    ), 6L)
  ),
  if (length(idna_data)) {
    sprintf(
      "const uint32_t IDNA_MAP_DATA[] = {\n%s\n};",
      chunk(hexlit(idna_data), 8L)
    )
  } else {
    "const uint32_t IDNA_MAP_DATA[] = {0};"
  },
  emit_trie("IDNA_TRIE", idna_trie),
  sprintf("const uint32_t IDNA_UNLISTED = %d;", idna_default),
  "",
  "// --- NFC_Quick_Check (UAX #15, two-stage trie) ---",
  "// Yes is the default and covers nearly the whole code space, so nearly",
  "// every block is the same block and dedup does the rest.",
  emit_trie("NFC_QC_TRIE", qc_trie),
  "",
  "// --- Bidi_Class (RFC 5893, two-stage trie) ---",
  emit_trie("BIDI_TRIE", bidi_trie),
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
  bounds_const("JOINING", joining_ranges$lo, joining_ranges$hi),
  "",
  "}  // namespace",
  "",
  "uint8_t combining_class(uint32_t cp) {",
  sprintf("  if (%s) return 0;", trie_guard("CCC_TRIE", ccc_trie)),
  sprintf("  return %s;", trie_call("CCC_TRIE")),
  "}",
  "",
  "bool is_combining_mark(uint32_t cp) {",
  sprintf(
    "  if (%s) return false;",
    guard_expr("MARK", mark_ranges$lo, mark_ranges$hi)
  ),
  "  return range_lookup(MARK_RANGES, MARK_N, cp) != nullptr;",
  "}",
  "",
  "const uint32_t *canonical_decomposition(uint32_t cp, uint32_t &len) {",
  "  uint32_t i = 0;",
  sprintf("  if (%s) {", trie_in_range("DECOMP_TRIE", decomp_trie)),
  sprintf("    i = %s;", trie_call("DECOMP_TRIE")),
  "  }",
  "  if (i == 0) {",
  "    len = 0;",
  "    return nullptr;",
  "  }",
  "  const DecompEntry &e = DECOMP_INDEX[i - 1];",
  "  len = e.len;",
  "  return &DECOMP_DATA[e.off];",
  "}",
  "",
  "uint32_t canonical_compose(uint32_t a, uint32_t b) {",
  "  if (b < COMP_B_FIRST || b > COMP_B_LAST) return 0;",
  sprintf("  if (%s) return 0;", trie_guard("COMP_TRIE", comp_trie, "a")),
  sprintf("  const uint32_t i = %s;", trie_call("COMP_TRIE", "a")),
  "  if (i == 0) return 0;",
  "  const CompIndex &e = COMP_INDEX[i - 1];",
  "  for (uint32_t j = 0; j < e.len; ++j) {",
  "    const CompPair &p = COMP_DATA[e.off + j];",
  "    if (p.b == b) return p.c;",
  "    if (p.b > b) break;  // the run is sorted by b",
  "  }",
  "  return 0;",
  "}",
  "",
  "IdnaStatus idna_lookup(uint32_t cp, const uint32_t *&map, uint32_t &len) {",
  "  uint32_t id = IDNA_UNLISTED;",
  sprintf("  if (%s) {", trie_in_range("IDNA_TRIE", idna_trie)),
  sprintf("    id = %s;", trie_call("IDNA_TRIE")),
  "  }",
  "  const IdnaValue &v = IDNA_VALUES[id];",
  "  len = v.len;",
  "  map = v.len ? &IDNA_MAP_DATA[v.off] : nullptr;",
  "  return static_cast<IdnaStatus>(v.status);",
  "}",
  "",
  "NfcQuickCheck nfc_quick_check(uint32_t cp) {",
  sprintf(
    "  if (%s) return NfcQuickCheck::yes;", trie_guard("NFC_QC_TRIE", qc_trie)
  ),
  "  return static_cast<NfcQuickCheck>(",
  sprintf("      %s);", trie_call("NFC_QC_TRIE")),
  "}",
  "",
  "BidiClass bidi_class(uint32_t cp) {",
  sprintf(
    "  if (%s) return BidiClass::L;", trie_guard("BIDI_TRIE", bidi_trie)
  ),
  "  return static_cast<BidiClass>(",
  sprintf("      %s);", trie_call("BIDI_TRIE")),
  "}",
  "",
  "JoiningType joining_type(uint32_t cp) {",
  sprintf(
    "  if (%s) return JoiningType::U;",
    guard_expr("JOINING", joining_ranges$lo, joining_ranges$hi)
  ),
  "  const JoiningRange *r = range_lookup(JOINING_RANGES, JOINING_N, cp);",
  "  return r ? static_cast<JoiningType>(r->value) : JoiningType::U;",
  "}",
  "",
  sprintf("}  // namespace %s", table_ns),
  "}  // namespace punycoder"
)

writeLines(src, sprintf("src/%s.cpp", table_stem))

message(sprintf(
  paste0(
    sprintf("generated src/%s.{h,cpp}: ", table_stem), "marks=%d ranges, ",
    "comp=%d pairs over %d first elements (runs: median %g, max %d), ",
    "joining=%d ranges, idna=%d ranges -> %d distinct values ",
    "(map data %d), decomp=%d (data %d)"
  ),
  nrow(mark_ranges), length(comp_a), length(comp_keys),
  stats::median(comp_run), max(comp_run), nrow(joining_ranges),
  length(idna_lo), length(idna_value_status), length(idna_data),
  length(decomp_keys), length(decomp_data)
))

for (t in list(ccc_trie, decomp_trie, idna_trie, bidi_trie, comp_trie,
               qc_trie)) {
  message(sprintf(
    "  %-24s trie: block %4d, stage1 %6d x %-8s stage2 %6d x %-8s %6.1f KB",
    t$name, t$block, length(t$stage1), elem_type(t$stage1),
    length(t$stage2), elem_type(t$stage2), t$bytes / 1024
  ))
}
