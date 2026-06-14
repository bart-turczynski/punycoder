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
  return h ? h : canonical_compose(a, b);
}

}  // namespace

std::vector<uint32_t> nfc(const std::vector<uint32_t> &input) {
  if (input.empty()) return {};

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
