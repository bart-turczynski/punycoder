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

// The three UTS #46 processing flags this package exposes as knobs. Each
// defaults to the strict profile (true); flipping one off relaxes exactly the
// corresponding UTS #46 check and nothing else. CheckBidi and CheckJoiners are
// deliberately NOT knobs (they stay on under every profile, PUNY-xghzvkuw), so
// they do not appear here. These are UTS #46 parameters, not a browser mode:
// full WHATWG host policy lives upstack in rurl.
struct NormalizeOptions {
    bool check_hyphens = true;      // V2/V3: "--" in 3rd/4th, leading/trailing
    bool use_std3 = true;           // UseSTD3ASCIIRules: ASCII restricted to LDH
    bool verify_dns_length = true;  // label 1-63 octets, host <= 253
};

// Normalize a single host to its canonical comparison form per the ratified
// contract under the given profile flags. Never throws on invalid *data*
// (returns {false, ""}); that NA-on-invalid style contract is implemented by
// catching internal PunycoderError exceptions, so embedders must compile this
// code with C++ exception handling enabled. The input is a well-formed
// (possibly empty) UTF-8 std::string. With the default `opts` (all flags true)
// this is the strict uts46-nontransitional-std3-v1 profile.
HostNormalizeResult host_normalize_one(const std::string& input,
                                       const NormalizeOptions& opts);

}  // namespace punycoder

#endif  // PUNYCODER_NORMALIZE_H
