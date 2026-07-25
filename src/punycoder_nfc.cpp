#include "punycoder_nfc.h"

#include "unicode_tables_16_0_0.h"

namespace punycoder {
namespace {

using u16::canonical_compose;
using u16::canonical_decomposition;
using u16::combining_class;

// Hangul algorithmic (de)composition constants (UAX #15, section 16).
constexpr uint32_t SBase = 0xAC00, LBase = 0x1100, VBase = 0x1161,
                   TBase = 0x11A7;
constexpr uint32_t LCount = 19, VCount = 21, TCount = 28;
constexpr uint32_t NCount = VCount * TCount;  // 588
constexpr uint32_t SCount = LCount * NCount;  // 11172

bool is_hangul_syllable(uint32_t cp) { return cp >= SBase && cp < SBase + SCount; }

// Append the canonical decomposition of cp to out, recursing through Hangul.
void decompose_into(uint32_t cp, std::vector<uint32_t> &out) {
  if (is_hangul_syllable(cp)) {
    uint32_t s = cp - SBase;
    out.push_back(LBase + s / NCount);
    out.push_back(VBase + (s % NCount) / TCount);
    uint32_t t = s % TCount;
    if (t != 0) out.push_back(TBase + t);
    return;
  }
  uint32_t len = 0;
  const uint32_t *d = canonical_decomposition(cp, len);
  if (d == nullptr) {
    out.push_back(cp);  // table holds fully-expanded decompositions already
    return;
  }
  for (uint32_t i = 0; i < len; ++i) out.push_back(d[i]);
}

// Canonical ordering: stable-sort each maximal run of combining marks (ccc != 0)
// by combining class. Starters (ccc == 0) are fixed points that bound the runs.
void canonical_order(std::vector<uint32_t> &v) {
  const size_t n = v.size();
  for (size_t i = 1; i < n; ++i) {
    uint8_t cc = combining_class(v[i]);
    if (cc == 0) continue;
    uint32_t cp = v[i];
    size_t j = i;
    while (j > 0) {
      uint8_t prev = combining_class(v[j - 1]);
      if (prev == 0 || prev <= cc) break;  // stable: stop at equal class
      v[j] = v[j - 1];
      --j;
    }
    v[j] = cp;
  }
}

// Hangul canonical composition; returns 0 if (a, b) is not a Hangul pair.
uint32_t hangul_compose(uint32_t a, uint32_t b) {
  if (a >= LBase && a < LBase + LCount && b >= VBase && b < VBase + VCount) {
    return SBase + ((a - LBase) * VCount + (b - VBase)) * TCount;
  }
  if (is_hangul_syllable(a) && (a - SBase) % TCount == 0 && b > TBase &&
      b < TBase + TCount) {
    return a + (b - TBase);
  }
  return 0;
}

uint32_t compose_pair(uint32_t a, uint32_t b) {
  uint32_t h = hangul_compose(a, b);
  if (h != 0) return h;
  // Most attempted compositions end here: b is any character following a
  // starter, and only a combining character can be the second element of a
  // pair. Measured over a 20k-host corpus, 87% of the attempts nfc() makes
  // never reach the table -- so applying the bound here rather than inside
  // canonical_compose() removes the call, not just the lookup. The bound
  // itself is derived and emitted with the table (ADR-011); the Hangul test
  // above stays in front of it because Hangul composition is algorithmic and
  // owes nothing to the pair table's bounds.
  if (!u16::composes_as_second(b)) return 0;
  return canonical_compose(a, b);
}

// UAX #15 "Detecting Normalization Forms". A sequence is already in NFC when
// every character is NFC_Quick_Check=Yes and no run of combining marks is out
// of canonical order.
//
// `maybe` is a real third value -- the character MAY compose with what
// precedes it -- so it falls through to the full pipeline alongside `no`.
// Folding it into `yes` would be silently correct on almost every input and
// wrong on exactly the input the pipeline exists to fix.
//
// The pass pays for itself because nearly all real host text is already in
// NFC: it replaces two vector allocations and three passes with one pass and
// none. For ASCII, nfc_inert() answers every character with one compare and no
// table read -- which is why the bound is applied here, inlined, rather than
// left to the guards inside combining_class() and nfc_quick_check(), where it
// would sit behind a function call.
bool is_nfc(const std::vector<uint32_t> &v) {
  uint8_t last_cc = 0;
  for (uint32_t cp : v) {
    if (u16::nfc_inert(cp)) {
      last_cc = 0;
      continue;
    }
    const uint8_t cc = combining_class(cp);
    if (cc != 0 && cc < last_cc) return false;  // out of canonical order
    if (u16::nfc_quick_check(cp) != u16::NfcQuickCheck::yes) return false;
    last_cc = cc;
  }
  return true;
}

}  // namespace

std::vector<uint32_t> nfc(const std::vector<uint32_t> &input) {
  if (input.empty()) return {};

  // 0. Quick check. NFC is idempotent, so a sequence that is already in NFC is
  //    its own answer and the three passes below would only rebuild it.
  if (is_nfc(input)) return input;

  // 1. Full canonical decomposition.
  std::vector<uint32_t> d;
  d.reserve(input.size() * 2);
  for (uint32_t cp : input) decompose_into(cp, d);

  // 2. Canonical ordering of combining marks.
  canonical_order(d);

  // 3. Canonical composition (UAX #15 D117). A non-blocked combining mark can
  //    compose with the last starter; lastCC is left unchanged on composition
  //    because the consumed mark is removed from the sequence.
  std::vector<uint32_t> out;
  out.reserve(d.size());
  size_t starter = SIZE_MAX;  // index in out of the last starter
  uint8_t last_cc = 0;        // ccc of the char most recently appended to out
  for (uint32_t cp : d) {
    uint8_t cc = combining_class(cp);
    if (starter != SIZE_MAX && (last_cc == 0 || last_cc < cc)) {
      uint32_t composed = compose_pair(out[starter], cp);
      if (composed != 0) {
        out[starter] = composed;
        continue;  // cp consumed; last_cc unchanged
      }
    }
    if (cc == 0) starter = out.size();
    last_cc = cc;
    out.push_back(cp);
  }
  return out;
}

}  // namespace punycoder
