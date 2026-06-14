#include "punycoder_normalize.h"

#include <string>
#include <vector>

#include "punycoder_core.h"
#include "punycoder_nfc.h"
#include "unicode_tables_16_0_0.h"

namespace punycoder {

namespace {

using u16::IdnaStatus;

constexpr uint32_t kFullStop = 0x2E;  // U+002E FULL STOP, the label separator.
constexpr uint32_t kHyphen = 0x2D;    // U+002D HYPHEN-MINUS.

// DNS limits enforced by VerifyDnsLength (contract section 3/5).
constexpr std::size_t kMaxLabelOctets = 63;
constexpr std::size_t kMaxHostOctets = 253;

HostNormalizeResult invalid() { return {false, std::string()}; }

// UTS-46 mapping (contract step 3a) over the pinned Unicode 16.0.0 table.
// Returns false if any code point is disallowed under the profile. With
// UseSTD3ASCIIRules = true the disallowed_std3_* statuses are treated as
// disallowed; non-LDH ASCII that the 16.0.0 table marks `valid` is rejected
// later by the per-label STD3 check, not here.
bool map_codepoints(const std::vector<uint32_t>& in, std::vector<uint32_t>& out) {
    out.clear();
    out.reserve(in.size());
    for (uint32_t cp : in) {
        const uint32_t* map = nullptr;
        uint32_t len = 0;
        switch (u16::idna_lookup(cp, map, len)) {
        case IdnaStatus::valid:
        case IdnaStatus::deviation:  // non-transitional: keep ß, ς, ZWJ, ZWNJ
            out.push_back(cp);
            break;
        case IdnaStatus::ignored:
            break;  // dropped
        case IdnaStatus::mapped:
            for (uint32_t i = 0; i < len; ++i) out.push_back(map[i]);
            break;
        case IdnaStatus::disallowed:
        case IdnaStatus::disallowed_std3_valid:
        case IdnaStatus::disallowed_std3_mapped:
            return false;
        }
    }
    return true;
}

// Validate one U-label against the profile (contract step 3d, UTS-46 §4.1
// criteria V1-V6 plus the STD3 ASCII restriction). `from_alabel` is true when
// the label is the Punycode-decoded payload of an xn-- label, which additional
// requires every code point to have UTS-46 status valid/deviation (a mapped,
// ignored, or disallowed code point means the A-label was non-canonical).
//
// CheckBidi / CheckJoiners are layered here by PSLR-izaqpicn; until then every
// bidi/joiner context is accepted.
bool validate_label(const std::vector<uint32_t>& label, bool from_alabel) {
    if (label.empty()) return false;  // empty label (leading/consecutive dots)

    // V1: label must be in NFC. (Whole-string NFC was applied before the
    // split; for decoded A-labels this is the operative check.)
    if (nfc(label) != label) return false;

    // V5: must not begin with a combining mark.
    if (u16::is_combining_mark(label.front())) return false;

    // V2/V3 (CheckHyphens): no "--" in the 3rd/4th positions, and no leading or
    // trailing hyphen.
    if (label.size() >= 4 && label[2] == kHyphen && label[3] == kHyphen) {
        return false;
    }
    if (label.front() == kHyphen || label.back() == kHyphen) return false;

    for (uint32_t cp : label) {
        if (cp < 0x80) {
            // STD3 (UseSTD3ASCIIRules): ASCII labels may contain only
            // letters, digits, and hyphen. Mapping has already case-folded
            // A-Z to a-z, so only lowercase letters appear here.
            const bool ldh = (cp >= 'a' && cp <= 'z') ||
                             (cp >= '0' && cp <= '9') || cp == kHyphen;
            if (!ldh) return false;
        } else if (from_alabel) {
            // V6: a canonical A-label decodes only to valid/deviation code
            // points. A mapped/ignored/disallowed code point here means the
            // A-label was not in canonical form.
            const uint32_t* map = nullptr;
            uint32_t len = 0;
            const IdnaStatus st = u16::idna_lookup(cp, map, len);
            if (st != IdnaStatus::valid && st != IdnaStatus::deviation) {
                return false;
            }
        }
        // V4 (no U+002E inside a label) holds by construction: labels are the
        // pieces between full stops.
    }

    // TODO(PSLR-izaqpicn): CheckBidi + CheckJoiners (ContextJ) over `label`.
    return true;
}

// True for an ASCII-only label that carries the lowercase ACE prefix. Mapping
// has already lowercased the input, so only "xn--" (never "XN--") reaches here.
bool has_ace_prefix(const std::vector<uint32_t>& label) {
    return label.size() >= 4 && label[0] == 'x' && label[1] == 'n' &&
           label[2] == kHyphen && label[3] == kHyphen;
}

// Process one label (already mapped + NFC). On success appends its canonical
// A-label form to `out`. Returns false if the label is invalid.
bool process_label(const std::vector<uint32_t>& label, std::string& out) {
    if (has_ace_prefix(label)) {
        // xn-- label: decode, validate the U-label, and require that it
        // re-encodes to the identical A-label (RFC 5891 §5.4 canonical form).
        const std::string alabel = codepoints_to_utf8(label);  // ASCII
        std::string ulabel_utf8;
        try {
            ulabel_utf8 = punycode_decode_label_fallback(alabel);
        } catch (const PunycoderError&) {
            return false;
        }

        std::vector<uint32_t> ulabel;
        try {
            ulabel = utf8_to_codepoints(ulabel_utf8);
        } catch (const PunycoderError&) {
            return false;
        }
        if (!validate_label(ulabel, /*from_alabel=*/true)) return false;

        std::string reencoded;
        try {
            reencoded = punycode_encode_label_fallback(ulabel_utf8);
        } catch (const PunycoderError&) {
            return false;
        }
        if (reencoded != alabel) return false;  // non-canonical A-label

        out = alabel;
        return true;
    }

    if (!validate_label(label, /*from_alabel=*/false)) return false;

    const std::string utf8 = codepoints_to_utf8(label);
    if (has_non_ascii(utf8)) {
        try {
            out = punycode_encode_label_fallback(utf8);
        } catch (const PunycoderError&) {
            return false;
        }
    } else {
        out = utf8;  // ASCII label, already lowercased by mapping
    }
    return true;
}

}  // namespace

HostNormalizeResult host_normalize_one(const std::string& input, bool strict) {
    (void)strict;  // v1 always applies the full profile (contract section 2/8).

    // Step 1: reject ill-formed / non-UTF-8 input.
    std::vector<uint32_t> cps;
    try {
        cps = utf8_to_codepoints(input);
    } catch (const PunycoderError&) {
        return invalid();
    }

    // Step 2: terminal-dot capture. Strip exactly one trailing root dot;
    // reject "." alone, two-or-more trailing dots, and empty remainder.
    bool had_root = false;
    if (!cps.empty() && cps.back() == kFullStop) {
        if (cps.size() == 1) return invalid();                 // "." only
        if (cps[cps.size() - 2] == kFullStop) return invalid();  // ">=2 dots"
        had_root = true;
        cps.pop_back();
    }
    if (cps.empty()) return invalid();

    // Step 3a: UTS-46 map. Step 3b: NFC.
    std::vector<uint32_t> mapped;
    if (!map_codepoints(cps, mapped)) return invalid();
    const std::vector<uint32_t> normalized = nfc(mapped);

    // Steps 3c-3d, 4: split into labels on U+002E, validate each, and build
    // the canonical A-label for every label.
    std::vector<std::string> out_labels;
    std::vector<uint32_t> label;
    label.reserve(normalized.size());
    for (std::size_t i = 0; i <= normalized.size(); ++i) {
        if (i == normalized.size() || normalized[i] == kFullStop) {
            std::string encoded;
            if (!process_label(label, encoded)) return invalid();
            out_labels.push_back(std::move(encoded));
            label.clear();
        } else {
            label.push_back(normalized[i]);
        }
    }

    // Step 5: VerifyDnsLength. Each A-label 1-63 octets; total joined (the
    // labels plus the separating dots, excluding the optional root dot) <= 253.
    std::size_t total = out_labels.empty() ? 0 : out_labels.size() - 1;
    for (const std::string& l : out_labels) {
        if (l.empty() || l.size() > kMaxLabelOctets) return invalid();
        total += l.size();
    }
    if (total > kMaxHostOctets) return invalid();

    // Step 6: reassemble with dots; re-append the single root dot if present.
    std::string result;
    result.reserve(total + (had_root ? 1 : 0));
    for (std::size_t i = 0; i < out_labels.size(); ++i) {
        if (i != 0) result.push_back('.');
        result += out_labels[i];
    }
    if (had_root) result.push_back('.');

    return {true, result};
}

}  // namespace punycoder
