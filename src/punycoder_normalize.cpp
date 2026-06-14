#include "punycoder_normalize.h"

#include <string>
#include <vector>

#include "punycoder_core.h"
#include "punycoder_nfc.h"
#include "unicode_tables_16_0_0.h"

namespace punycoder {

namespace {

using u16::BidiClass;
using u16::IdnaStatus;
using u16::JoiningType;

constexpr uint32_t kFullStop = 0x2E;  // U+002E FULL STOP, the label separator.
constexpr uint32_t kHyphen = 0x2D;    // U+002D HYPHEN-MINUS.
constexpr uint32_t kZwnj = 0x200C;    // ZERO WIDTH NON-JOINER.
constexpr uint32_t kZwj = 0x200D;     // ZERO WIDTH JOINER.
constexpr uint8_t kVirama = 9;        // canonical combining class of viramas.

// DNS limits enforced by VerifyDnsLength (contract section 3/5).
constexpr std::size_t kMaxLabelOctets = 63;
constexpr std::size_t kMaxHostOctets = 253;

// One label resolved to its U-label code points. A-labels are Punycode-decoded
// up front so CheckBidi (a whole-domain property) can see every label's
// characters before any label is validated.
struct LabelWork {
    std::vector<uint32_t> cps;  // U-label code points
    bool from_alabel = false;   // label carried the xn-- ACE prefix
    std::string alabel;         // canonical A-label text (only if from_alabel)
};

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

// CheckJoiners (UTS-46 §4.1 / RFC 5892 Appendix A): every ZWNJ/ZWJ in the
// label must satisfy its contextual rule.
bool check_joiners(const std::vector<uint32_t>& label) {
    for (std::size_t i = 0; i < label.size(); ++i) {
        const uint32_t cp = label[i];
        if (cp != kZwnj && cp != kZwj) continue;

        // Both rules: valid if the preceding character is a Virama.
        const bool virama_before =
            i > 0 && u16::combining_class(label[i - 1]) == kVirama;

        if (cp == kZwj) {  // RFC 5892 A.2
            if (!virama_before) return false;
            continue;
        }

        // ZWNJ, RFC 5892 A.1. Virama-before is sufficient; otherwise the
        // context must match (L|D) T* ZWNJ T* (R|D).
        if (virama_before) continue;

        bool ok_left = false;
        for (std::size_t j = i; j-- > 0;) {
            const JoiningType jt = u16::joining_type(label[j]);
            if (jt == JoiningType::T) continue;
            ok_left = jt == JoiningType::L || jt == JoiningType::D;
            break;
        }
        bool ok_right = false;
        for (std::size_t j = i + 1; j < label.size(); ++j) {
            const JoiningType jt = u16::joining_type(label[j]);
            if (jt == JoiningType::T) continue;
            ok_right = jt == JoiningType::R || jt == JoiningType::D;
            break;
        }
        if (!ok_left || !ok_right) return false;
    }
    return true;
}

// CheckBidi (RFC 5893, "Bidi Rule"). Applied to a label only when the whole
// domain is a Bidi domain (some label contains an R/AL/AN character).
bool check_bidi(const std::vector<uint32_t>& label) {
    if (label.empty()) return false;

    // Rule 1: the first character fixes the label direction.
    const BidiClass first = u16::bidi_class(label.front());
    bool rtl;
    if (first == BidiClass::R || first == BidiClass::AL) {
        rtl = true;
    } else if (first == BidiClass::L) {
        rtl = false;
    } else {
        return false;
    }

    bool has_en = false;
    bool has_an = false;
    std::size_t last_strong = 0;  // index of the last non-NSM character
    for (std::size_t i = 0; i < label.size(); ++i) {
        const BidiClass c = u16::bidi_class(label[i]);
        if (rtl) {
            // Rule 2: allowed characters in an RTL label.
            switch (c) {
            case BidiClass::R:
            case BidiClass::AL:
            case BidiClass::AN:
            case BidiClass::EN:
            case BidiClass::ES:
            case BidiClass::CS:
            case BidiClass::ET:
            case BidiClass::ON:
            case BidiClass::BN:
            case BidiClass::NSM:
                break;
            default:
                return false;
            }
            if (c == BidiClass::EN) has_en = true;
            if (c == BidiClass::AN) has_an = true;
        } else {
            // Rule 5: allowed characters in an LTR label.
            switch (c) {
            case BidiClass::L:
            case BidiClass::EN:
            case BidiClass::ES:
            case BidiClass::CS:
            case BidiClass::ET:
            case BidiClass::ON:
            case BidiClass::BN:
            case BidiClass::NSM:
                break;
            default:
                return false;
            }
        }
        if (c != BidiClass::NSM) last_strong = i;
    }

    // Rule 4: an RTL label must not mix EN and AN.
    if (rtl && has_en && has_an) return false;

    // Rules 3 / 6: the last non-NSM character must be of the allowed ending
    // type (trailing NSM characters are permitted).
    const BidiClass end = u16::bidi_class(label[last_strong]);
    if (rtl) {
        return end == BidiClass::R || end == BidiClass::AL ||
               end == BidiClass::EN || end == BidiClass::AN;
    }
    return end == BidiClass::L || end == BidiClass::EN;
}

// Validate one U-label against the profile (contract step 3d, UTS-46 §4.1
// criteria V1-V6, STD3, and CheckJoiners). `from_alabel` is true when the
// label is the Punycode-decoded payload of an xn-- label, which additionally
// requires every code point to have UTS-46 status valid/deviation (a mapped,
// ignored, or disallowed code point means the A-label was non-canonical).
// CheckBidi is whole-domain and is applied separately by the caller.
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

    return check_joiners(label);
}

// True for an ASCII-only label that carries the lowercase ACE prefix. Mapping
// has already lowercased the input, so only "xn--" (never "XN--") reaches here.
bool has_ace_prefix(const std::vector<uint32_t>& label) {
    return label.size() >= 4 && label[0] == 'x' && label[1] == 'n' &&
           label[2] == kHyphen && label[3] == kHyphen;
}

// Resolve one split label (already mapped + NFC) to its U-label form. Decodes
// xn-- labels; returns false on an empty label or a Punycode/UTF-8 decode error.
bool resolve_label(const std::vector<uint32_t>& piece, LabelWork& work) {
    if (piece.empty()) return false;

    if (!has_ace_prefix(piece)) {
        work.cps = piece;
        work.from_alabel = false;
        return true;
    }

    work.from_alabel = true;
    work.alabel = codepoints_to_utf8(piece);  // ASCII
    try {
        const std::string ulabel = punycode_decode_label_fallback(work.alabel);
        work.cps = utf8_to_codepoints(ulabel);
    } catch (const PunycoderError&) {
        return false;
    }
    return true;
}

// Validate one resolved label and emit its canonical A-label form. `bidi_domain`
// selects whether CheckBidi applies (contract section 3).
bool finalize_label(const LabelWork& work, bool bidi_domain, std::string& out) {
    if (!validate_label(work.cps, work.from_alabel)) return false;
    if (bidi_domain && !check_bidi(work.cps)) return false;

    if (work.from_alabel) {
        // Require the U-label to re-encode to the identical A-label (RFC 5891
        // §5.4 canonical form).
        std::string reencoded;
        try {
            reencoded = punycode_encode_label_fallback(codepoints_to_utf8(work.cps));
        } catch (const PunycoderError&) {
            return false;
        }
        if (reencoded != work.alabel) return false;
        out = work.alabel;
        return true;
    }

    const std::string utf8 = codepoints_to_utf8(work.cps);
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
        if (cps.size() == 1) return invalid();                   // "." only
        if (cps[cps.size() - 2] == kFullStop) return invalid();  // ">=2 dots"
        had_root = true;
        cps.pop_back();
    }
    if (cps.empty()) return invalid();

    // Step 3a: UTS-46 map. Step 3b: NFC.
    std::vector<uint32_t> mapped;
    if (!map_codepoints(cps, mapped)) return invalid();
    const std::vector<uint32_t> normalized = nfc(mapped);

    // Step 3c: split into labels on U+002E and resolve each to its U-label form
    // (decoding xn-- labels) so CheckBidi can examine the whole domain.
    std::vector<LabelWork> labels;
    std::vector<uint32_t> piece;
    piece.reserve(normalized.size());
    for (std::size_t i = 0; i <= normalized.size(); ++i) {
        if (i == normalized.size() || normalized[i] == kFullStop) {
            LabelWork work;
            if (!resolve_label(piece, work)) return invalid();
            labels.push_back(std::move(work));
            piece.clear();
        } else {
            piece.push_back(normalized[i]);
        }
    }

    // CheckBidi prerequisite: the domain is a Bidi domain if any label contains
    // a character with Bidi property R, AL, or AN (RFC 5893 §1.4).
    bool bidi_domain = false;
    for (const LabelWork& work : labels) {
        for (uint32_t cp : work.cps) {
            const BidiClass c = u16::bidi_class(cp);
            if (c == BidiClass::R || c == BidiClass::AL || c == BidiClass::AN) {
                bidi_domain = true;
                break;
            }
        }
        if (bidi_domain) break;
    }

    // Steps 3d + 4: validate each label and build its canonical A-label.
    std::vector<std::string> out_labels;
    out_labels.reserve(labels.size());
    for (const LabelWork& work : labels) {
        std::string encoded;
        if (!finalize_label(work, bidi_domain, encoded)) return invalid();
        out_labels.push_back(std::move(encoded));
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
