// Canonical-host normalization (UTS-46, non-transitional, STD3).
// Implements dev/normalization-contract.md section 4 over a vendored Unicode
// table set: UTS-46 mapping, NFC, label validation, A-label canonical check,
// Punycode encode, and DNS length verification. CheckBidi and CheckJoiners
// (contract section 3) are implemented in full and always on.
#ifndef PUNYCODER_NORMALIZE_H
#define PUNYCODER_NORMALIZE_H

#include <string>

#include "punycoder_unicode_version.h"

namespace punycoder {

// Outcome of normalizing one host. `valid == false` is the contract's
// NA-on-invalid signal; the caller chooses what to do with it. `value` holds
// the canonical lowercase ASCII A-label host only when `valid == true`.
struct HostNormalizeResult {
    bool valid;
    std::string value;
};

// What determines the output of host_normalize_one(): three UTS #46 processing
// flags, plus the table set they are applied over.
//
// The flags each default to the strict profile (true); flipping one off relaxes
// exactly the corresponding UTS #46 check and nothing else. CheckBidi and
// CheckJoiners are deliberately NOT knobs (they stay on under every profile,
// PUNY-xghzvkuw), so they do not appear here. These are UTS #46 parameters, not
// a browser mode: full WHATWG host policy lives upstack in rurl.
//
// `unicode_version` is a different kind of member from the three flags -- it
// does not relax a check, it selects the DATA every check reads. It lives here
// because UTS #46 treats the Unicode version as a parameter of conformance, so
// it is part of the profile identity that normalization_profile_info() reports,
// exactly as the flags are. It is dispatched on once, at host_normalize_one()
// entry; nothing downstream of that is aware of it.
struct NormalizeOptions {
    bool check_hyphens = true;      // V2/V3: "--" in 3rd/4th, leading/trailing
    bool use_std3 = true;           // UseSTD3ASCIIRules: ASCII restricted to LDH
    bool verify_dns_length = true;  // label 1-63 octets, host <= 253
    UnicodeVersion unicode_version = kDefaultUnicodeVersion;
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
