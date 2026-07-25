// Unicode Normalization Form C (NFC) for canonical-host normalization.
// See dev/normalization-contract.md section 4 step 3b.
#ifndef PUNYCODER_NFC_H
#define PUNYCODER_NFC_H

#include <cstdint>
#include <vector>

namespace punycoder {

// Return the NFC (canonical decomposition followed by canonical composition,
// per UAX #15) of a code-point sequence, under the table set T -- one of the
// generated per-version `Tables` facades. Pure function of its input and of T.
//
// DECLARED here, DEFINED and explicitly instantiated in punycoder_nfc.cpp, once
// per shipped version. That is deliberate: the definition stays out of every
// other translation unit, the helpers it uses stay in that file's unnamed
// namespace, and there is exactly one instantiation of each specialization in
// the shared object. Asking for a T that was never instantiated is a link error
// naming the missing symbol -- not a silent fallback, and not a second copy of
// the pipeline compiled into the caller.
//
// T is not deducible from the argument, so callers write nfc<T>(v). That is a
// feature: nothing can instantiate this implicitly.
template <class T>
std::vector<uint32_t> nfc(const std::vector<uint32_t> &input);

}  // namespace punycoder

#endif  // PUNYCODER_NFC_H
