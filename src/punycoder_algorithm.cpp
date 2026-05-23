#include "punycoder_core.h"

#include <algorithm>
#include <cctype>
#include <cstddef>
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
        throw_error(ErrorCode::punycode_overflow);
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
    throw_error(ErrorCode::invalid_punycode_digit);
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

EncodingInput prepare_encode_input(const std::string& label) {
    if (label.empty()) {
        throw_error(ErrorCode::empty_domain_label);
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
    std::string output;
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

    while (handled < codepoints.size()) {
        uint32_t m = std::numeric_limits<uint32_t>::max();
        for (uint32_t cp : codepoints) {
            if (cp >= n && cp < m) {
                m = cp;
            }
        }

        if (m == std::numeric_limits<uint32_t>::max()) {
            throw_error(ErrorCode::punycode_overflow);
        }

        // RFC 3492 §6.3 "Encoding procedure" — delta accumulates the distance
        // between successive insertion points, scaled by (handled + 1).
        uint64_t span = checked_mul_u64(
            static_cast<uint64_t>(m - n), static_cast<uint64_t>(handled) + 1
        );
        delta = checked_add_u64(delta, span);
        n = m;

        for (uint32_t cp : codepoints) {
            if (cp < n) {
                delta = checked_add_u64(delta, 1);
            }

            if (cp == n) {
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
        }

        ++delta;
        ++n;
    }

    return "xn--" + output;
}

std::string punycode_decode_label_fallback(const std::string& label) {
    if (!starts_with_xn_prefix(label)) {
        return label;
    }

    std::string input = label.substr(4);
    if (input.empty()) {
        throw_error(ErrorCode::invalid_punycode_label);
    }

    std::vector<uint32_t> output;
    output.reserve(input.size());
    size_t pos = input.find_last_of(kDelimiter);
    size_t index = 0;

    if (pos != std::string::npos) {
        for (size_t j = 0; j < pos; ++j) {
            unsigned char c = static_cast<unsigned char>(input[j]);
            if (c >= 0x80) {
                throw_error(ErrorCode::invalid_basic_code_point);
            }
            output.push_back(static_cast<uint32_t>(c));
        }
        index = pos + 1;
    }

    uint32_t n = kInitialN;
    uint64_t i = 0;
    uint32_t bias = kInitialBias;

    while (index < input.size()) {
        uint64_t oldi = i;
        uint64_t w = 1;

        for (uint32_t k = kBase;; k += kBase) {
            if (index >= input.size()) {
                throw_error(ErrorCode::truncated_punycode_input);
            }

            int digit = decode_digit(input[index++]);
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
            throw_error(ErrorCode::punycode_overflow);
        }
        n += static_cast<uint32_t>(increment);
        i %= out_len;

        if (!is_valid_unicode_scalar(n)) {
            throw_error(ErrorCode::decoded_code_point_out_of_range);
        }

        output.insert(output.begin() + static_cast<std::ptrdiff_t>(i), n);
        ++i;
    }

    return codepoints_to_utf8(output);
}

}  // namespace punycoder
