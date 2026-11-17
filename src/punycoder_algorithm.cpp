#include "punycoder_core.h"

#include <algorithm>
#include <cctype>
#include <limits>

namespace punycoder {

namespace {

constexpr uint32_t kBase = 36;
constexpr uint32_t kTmin = 1;
constexpr uint32_t kTmax = 26;
constexpr uint32_t kSkew = 38;
constexpr uint32_t kDamp = 700;
constexpr uint32_t kInitialBias = 72;
constexpr uint32_t kInitialN = 128;
constexpr char kDelimiter = '-';

inline uint64_t checked_add_u64(uint64_t a, uint64_t b) {
    if (a > std::numeric_limits<uint64_t>::max() - b) {
        throw_error(ErrorCode::punycode_overflow);  // # nocov (64-bit overflow guard)
    }
    return a + b;
}

inline uint64_t checked_mul_u64(uint64_t a, uint64_t b) {
    if (b != 0 && a > std::numeric_limits<uint64_t>::max() / b) {
        throw_error(ErrorCode::punycode_overflow);
    }
    return a * b;
}

struct EncodingInput {
    std::vector<uint32_t> codepoints;
    bool needs_encoding;
};

inline uint32_t compute_threshold(uint32_t k, uint32_t bias) {
    if (k <= bias) {
        return kTmin;
    }
    if (k >= bias + kTmax) {
        return kTmax;
    }
    return k - bias;
}

int decode_digit(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0' + 26;
    }
    if (c >= 'a' && c <= 'z') {
        return c - 'a';
    }
    if (c >= 'A' && c <= 'Z') {
        return c - 'A';
    }
    return -1;
}

char encode_digit(uint32_t digit) {
    if (digit < 26) {
        return static_cast<char>('a' + digit);
    }
    if (digit < 36) {
        return static_cast<char>('0' + (digit - 26));
    }
    throw_error(ErrorCode::invalid_punycode_digit);  // # nocov (digit is always < 36)
}

uint32_t adapt(uint64_t delta, uint64_t numpoints, bool first_time) {
    delta = first_time ? (delta / kDamp) : (delta / 2);
    delta += delta / numpoints;

    uint64_t k = 0;
    while (delta > ((kBase - kTmin) * kTmax) / 2) {
        delta /= (kBase - kTmin);
        k += kBase;
    }

    return static_cast<uint32_t>(
        k + (((kBase - kTmin + 1) * delta) / (delta + kSkew))
    );
}

// Fenwick (binary indexed) tree over label positions, counting the positions
// whose code point the encoder has already handled. The RFC 3492 encoder
// needs, for each insertion, the number of handled code points between two
// positions; this answers that in O(log n) instead of a scan of the label.
class HandledPositions {
public:
    explicit HandledPositions(const std::vector<uint32_t>& codepoints)
        : tree_(codepoints.size() + 1, 0) {
        // Basic code points are handled before the first insertion. Linear
        // construction: seed each leaf, then push it into its parent.
        for (size_t i = 0; i < codepoints.size(); ++i) {
            if (codepoints[i] < 0x80) {
                tree_[i + 1] += 1;
            }
        }
        for (size_t i = 1; i < tree_.size(); ++i) {
            size_t parent = i + (i & (~i + 1));
            if (parent < tree_.size()) {
                tree_[parent] += tree_[i];
            }
        }
    }

    void mark(size_t pos) {
        for (size_t i = pos + 1; i < tree_.size(); i += i & (~i + 1)) {
            tree_[i] += 1;
        }
    }

    // Handled positions in [0, end).
    size_t count_before(size_t end) const {
        size_t total = 0;
        for (size_t i = end; i > 0; i -= i & (~i + 1)) {
            total += tree_[i];
        }
        return total;
    }

    // Handled positions in [begin, end), begin <= end.
    size_t count_between(size_t begin, size_t end) const {
        return count_before(end) - count_before(begin);
    }

private:
    std::vector<size_t> tree_;
};

EncodingInput prepare_encode_input(const std::string& label) {
    if (label.empty()) {
        throw_error(ErrorCode::empty_domain_label);  // # nocov (domain layer rejects empty labels first)
    }

    if (!has_non_ascii(label)) {
        return {{}, false};
    }

    std::vector<uint32_t> codepoints = utf8_to_codepoints(label);
    return {std::move(codepoints), true};
}

}  // namespace

bool starts_with_xn_prefix(const std::string& label) {
    if (label.size() < 4) {
        return false;
    }

    return std::tolower(static_cast<unsigned char>(label[0])) == 'x' &&
           std::tolower(static_cast<unsigned char>(label[1])) == 'n' &&
           label[2] == '-' && label[3] == '-';
}

std::string punycode_encode_label_fallback(const std::string& label) {
    EncodingInput input = prepare_encode_input(label);

    if (!input.needs_encoding) {
        return label;
    }

    const std::vector<uint32_t>& codepoints = input.codepoints;
    std::string output = "xn--";
    output.reserve(codepoints.size() + 8);
    size_t basic_count = 0;
    size_t handled = 0;

    for (uint32_t cp : codepoints) {
        if (cp < 0x80) {
            output.push_back(static_cast<char>(cp));
            ++basic_count;
            ++handled;
        }
    }

    if (basic_count > 0) {
        output.push_back(kDelimiter);
    }

    uint32_t n = kInitialN;
    uint64_t delta = 0;
    uint32_t bias = kInitialBias;

    // RFC 3492 §6.3 "Encoding procedure", in O(L log L) for a label of L code
    // points. The RFC's loop rescans the whole label once per distinct
    // non-basic code point m, adding 1 to delta for every code point < m it
    // passes and emitting a delta at every occurrence of m. Here the
    // occurrences of each m come from one sort, and the code points < m
    // between two of them -- exactly the already-handled ones -- come from a
    // Fenwick count. Same additions, same order, so the same digits.
    std::vector<size_t> pending;
    pending.reserve(codepoints.size() - basic_count);
    for (size_t pos = 0; pos < codepoints.size(); ++pos) {
        if (codepoints[pos] >= 0x80) {
            pending.push_back(pos);
        }
    }
    std::sort(pending.begin(), pending.end(), [&codepoints](size_t a, size_t b) {
        return codepoints[a] != codepoints[b] ? codepoints[a] < codepoints[b] : a < b;
    });

    HandledPositions handled_at(codepoints);
    size_t next = 0;

    while (next < pending.size()) {
        uint32_t m = codepoints[pending[next]];
        size_t group_end = next;
        while (group_end < pending.size() && codepoints[pending[group_end]] == m) {
            ++group_end;
        }

        // delta accumulates the distance between successive insertion
        // points, scaled by (handled + 1).
        uint64_t span = checked_mul_u64(
            static_cast<uint64_t>(m - n), static_cast<uint64_t>(handled) + 1
        );
        delta = checked_add_u64(delta, span);
        n = m;

        size_t scan_from = 0;  // first position not yet passed in this pass
        for (size_t i = next; i < group_end; ++i) {
            size_t pos = pending[i];
            delta = checked_add_u64(delta, handled_at.count_between(scan_from, pos));
            scan_from = pos + 1;

            uint64_t q = delta;
            for (uint32_t k = kBase;; k += kBase) {
                uint32_t t = compute_threshold(k, bias);
                if (q < t) {
                    break;
                }

                uint32_t code =
                    t + static_cast<uint32_t>((q - t) % (kBase - t));
                output.push_back(encode_digit(code));
                q = (q - t) / (kBase - t);
            }

            output.push_back(encode_digit(static_cast<uint32_t>(q)));
            bias = adapt(delta, handled + 1, handled == basic_count);
            delta = 0;
            ++handled;
        }

        // The rest of the pass, after the last occurrence of m.
        delta = checked_add_u64(
            delta, handled_at.count_between(scan_from, codepoints.size())
        );
        // m is handled from the next pass on: it counts as < n there.
        for (size_t i = next; i < group_end; ++i) {
            handled_at.mark(pending[i]);
        }
        next = group_end;

        ++delta;
        ++n;
    }

    return output;
}

std::string punycode_decode_label_fallback(const std::string& label,
                                           bool require_ldh_basic) {
    if (!starts_with_xn_prefix(label)) {
        return label;  // # nocov (decode is only dispatched for xn-- labels)
    }

    // Self-protection for the O(n^2) insert loop below: refuse oversized input
    // regardless of caller, so a crafted label can never drive quadratic time
    // or unbounded allocation. The domain layer caps this earlier, but the
    // reference decoder must not rely on that for callers that reach it
    // directly (e.g. backend parity comparisons).
    if (label.size() > kMaxLabelLength) {
        throw_error(ErrorCode::label_length_limit);  // # nocov (domain layer caps length first)
    }

    constexpr size_t payload_start = 4;
    if (label.size() == payload_start) {
        throw_error(ErrorCode::invalid_punycode_label);
    }

    std::vector<uint32_t> output;
    output.reserve(label.size() - payload_start);
    size_t pos = label.find_last_of(kDelimiter);
    size_t index = payload_start;

    if (pos != std::string::npos && pos >= payload_start) {
        for (size_t j = payload_start; j < pos; ++j) {
            unsigned char c = static_cast<unsigned char>(label[j]);
            // A valid A-label is letter-digit-hyphen, so its literal (basic)
            // code points must be LDH. libidn2 enforces this; the in-tree
            // fallback matches it (PUNY-ypjwnagl) rather than passing
            // punctuation such as '(' ')' ',' '%' through. The Bootstring
            // payload after the delimiter is already constrained to a-z0-9 by
            // decode_digit().
            //
            // host_normalize(use_std3 = FALSE) clears require_ldh_basic: with
            // UseSTD3ASCIIRules off, UTS #46 admits other ASCII in a label, so
            // the basic part may hold it too (PUNY-nqbqcgow).
            //
            // The >= 0x80 guard is always on, whatever require_ldh_basic says:
            // basic code points are ASCII by definition (RFC 3492 section 5).
            // It is defense in depth for C++ callers. From R it is unreachable
            // as a distinct outcome: with the flag set the LDH test rejects the
            // byte anyway, and with it clear finalize_label's re-encode compare
            // rejects any A-label that is not pure ASCII.
            if (c >= 0x80) {
                throw_error(ErrorCode::invalid_basic_code_point);
            }
            bool ldh = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                       (c >= '0' && c <= '9') || c == '-';
            if (require_ldh_basic && !ldh) {
                throw_error(ErrorCode::invalid_basic_code_point);
            }
            output.push_back(static_cast<uint32_t>(c));
        }
        index = pos + 1;
    }

    uint32_t n = kInitialN;
    uint64_t i = 0;
    uint32_t bias = kInitialBias;

    while (index < label.size()) {
        uint64_t oldi = i;
        uint64_t w = 1;

        for (uint32_t k = kBase;; k += kBase) {
            if (index >= label.size()) {
                throw_error(ErrorCode::truncated_punycode_input);
            }

            int digit = decode_digit(label[index++]);
            if (digit < 0) {
                throw_error(ErrorCode::invalid_punycode_digit);
            }

            // RFC 3492 §6.2 "Decoding procedure" — i accumulates a generalized
            // variable-length integer; w is its place value.
            i = checked_add_u64(i, checked_mul_u64(static_cast<uint64_t>(digit), w));
            uint32_t t = compute_threshold(k, bias);

            if (static_cast<uint32_t>(digit) < t) {
                break;
            }

            w = checked_mul_u64(w, static_cast<uint64_t>(kBase - t));
        }

        uint64_t out_len = output.size() + 1;
        bias = adapt(i - oldi, out_len, oldi == 0);

        // n is uint32; check the destination range before narrowing.
        uint64_t increment = i / out_len;
        if (increment > std::numeric_limits<uint32_t>::max() - n) {
            throw_error(ErrorCode::punycode_overflow);  // # nocov (n overflow guard)
        }
        n += static_cast<uint32_t>(increment);
        i %= out_len;

        if (!is_valid_unicode_scalar(n)) {
            throw_error(ErrorCode::decoded_code_point_out_of_range);
        }

        output.insert(output.begin() + static_cast<std::ptrdiff_t>(i), n);
        ++i;
    }

    // An A-label that yields no code points -- e.g. "xn---", an ACE prefix
    // followed by an empty Bootstring payload -- is not a decodable label.
    // libidn2 rejects it; the fallback must too (PUNY-rxvwqsou) rather than
    // echoing the input back and hiding the failure from the caller.
    if (output.empty()) {
        throw_error(ErrorCode::invalid_punycode_label);
    }

    return codepoints_to_utf8(output);
}

}  // namespace punycoder
