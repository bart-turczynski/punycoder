// Canonical-host normalization (UTS-46, non-transitional, STD3).
// Implements docs/normalization-contract.md section 4 over the vendored
// Unicode 16.0.0 tables: UTS-46 mapping, NFC, label validation, A-label
// canonical check, Punycode encode, and DNS length verification.
//
// CheckBidi / CheckJoiners (contract section 3) are layered on top of the
// per-label validation by PSLR-izaqpicn; this file leaves the hook in
// validate_label() and currently accepts all bidi/joiner contexts.
#ifndef PUNYCODER_NORMALIZE_H
#define PUNYCODER_NORMALIZE_H

#include <string>

namespace punycoder {

// Outcome of normalizing one host. `valid == false` is the contract's
// NA-on-invalid signal; the caller chooses what to do with it. `value` holds
// the canonical lowercase ASCII A-label host only when `valid == true`.
struct HostNormalizeResult {
    bool valid;
    std::string value;
};

// Normalize a single host to its canonical comparison form per the ratified
// contract. Never throws on invalid *data* (returns {false, ""}); the input is
// a well-formed (possibly empty) UTF-8 std::string. `strict` is accepted for
// signature parity with the contract; v1 always applies the full profile
// (the relaxed strict = false variant is deferred, contract section 2/8).
HostNormalizeResult host_normalize_one(const std::string& input, bool strict);

}  // namespace punycoder

#endif  // PUNYCODER_NORMALIZE_H
