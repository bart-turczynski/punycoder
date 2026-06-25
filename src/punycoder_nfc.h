// Unicode Normalization Form C (NFC) for canonical-host normalization.
// See dev/normalization-contract.md section 4 step 3b.
#ifndef PUNYCODER_NFC_H
#define PUNYCODER_NFC_H

#include <cstdint>
#include <vector>

namespace punycoder {

// Return the NFC (canonical decomposition followed by canonical composition,
// per UAX #15) of a code-point sequence. Pure function of its input.
std::vector<uint32_t> nfc(const std::vector<uint32_t> &input);

}  // namespace punycoder

#endif  // PUNYCODER_NFC_H
