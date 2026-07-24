#ifndef PUNYCODER_CORE_H
#define PUNYCODER_CORE_H

#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

namespace punycoder {

enum class ErrorCode {
    invalid_punycode_digit,
    invalid_utf8_sequence,
    truncated_utf8_sequence,
    invalid_utf8_continuation,
    overlong_utf8_sequence,
    invalid_utf8_code_point,
    invalid_unicode_code_point,
    empty_domain_label,
    invalid_punycode_label,
    punycode_overflow,
    invalid_basic_code_point,
    truncated_punycode_input,
    decoded_code_point_out_of_range,
    domain_empty,
    domain_too_long,
    domain_empty_label,
    domain_label_too_long,
    domain_label_hyphen,
    ascii_domain_characters,
    looks_like_url,
    encoded_label_too_long,
    label_length_limit,
    backend_failure
};

enum class DomainTransform {
    none,
    encode,
    decode
};

enum class BackendPreference {
    automatic,
    libidn2,
    fallback
};

class PunycoderError : public std::runtime_error {
public:
    PunycoderError(ErrorCode code, const std::string& message);
    ErrorCode code() const noexcept;

private:
    ErrorCode code_;
};

[[noreturn]] void throw_error(ErrorCode code);
[[noreturn]] void throw_error(ErrorCode code, const std::string& detail);
const char* error_code_name(ErrorCode code) noexcept;

struct LabelInfo {
    std::string value;
    std::string transformed;
    bool is_ascii = true;
    bool has_xn_prefix = false;
    bool needs_encoding = false;
    bool needs_decoding = false;
};

struct ParsedDomain {
    std::vector<LabelInfo> labels;
    bool has_trailing_dot = false;
};

struct LabelBackend {
    std::string (*encode)(const std::string& label);
    std::string (*decode)(const std::string& label);
    const char* name;
};

// UTF-8 codec utilities. Used by every encode/decode path and by the
// label/domain validators.
std::vector<uint32_t> utf8_to_codepoints(const std::string& input);
std::string codepoints_to_utf8(const std::vector<uint32_t>& codepoints);
bool has_non_ascii(const std::string& input);

// Punycode internals. Not part of the public R surface; used only by
// the backend, the fallback algorithm, and domain classification.
constexpr inline bool is_valid_unicode_scalar(uint32_t cp) noexcept {
    return cp <= 0x10FFFF && (cp < 0xD800 || cp > 0xDFFF);
}
// Hard upper bound on a single label's byte length, enforced regardless of
// the strict flag. Legitimate DNS labels never exceed 63 octets (RFC 1035);
// this deliberately generous cap exists only to stop adversarial oversized
// input from driving the O(n^2) reference encoder/decoder into quadratic-time
// / unbounded-allocation territory on the non-strict path, where the precise
// RFC limits are not applied. See punycoder_domain.cpp and
// punycoder_algorithm.cpp.
constexpr std::size_t kMaxLabelLength = 1024;

bool starts_with_xn_prefix(const std::string& label);
std::string punycode_encode_label_fallback(const std::string& label);
std::string punycode_decode_label_fallback(const std::string& label);

// Backend selection. The libidn2 path is compiled in only when
// PUNYCODER_USE_LIBIDN2 is defined (see punycoder_backend.cpp).
bool libidn2_backend_available() noexcept;
LabelBackend select_label_backend(
    BackendPreference preference = BackendPreference::automatic
);

ParsedDomain validate_and_parse_domain(
    const std::string& domain,
    const LabelBackend& backend,
    bool strict,
    bool verify_dns_length,
    DomainTransform transform = DomainTransform::none
);
bool looks_like_url_input(const std::string& input);

class PunycodeService {
public:
    PunycodeService(bool strict, bool verify_dns_length);
    PunycodeService(
        bool strict,
        const LabelBackend& backend,
        bool verify_dns_length
    );

    std::string encode_domain(const std::string& unicode_domain) const;
    std::string decode_domain(const std::string& punycode_domain) const;

private:
    std::string transform_domain(
        const std::string& domain,
        DomainTransform transform
    ) const;

    LabelBackend backend_;
    bool strict_;
    bool verify_dns_length_;
};

}  // namespace punycoder

#endif
