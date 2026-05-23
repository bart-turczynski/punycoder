#ifndef PUNYCODER_CORE_H
#define PUNYCODER_CORE_H

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
    encoded_label_too_long,
    invalid_ipv6_authority,
    invalid_authority,
    empty_url,
    backend_failure
};

enum class DomainTransform {
    none,
    encode,
    decode
};

enum class HostKind {
    empty,
    dns,
    ipv4,
    ipv6
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

struct LabelInfo {
    std::string value;
    std::string transformed;
    bool is_ascii = true;
    bool has_xn_prefix = false;
    bool needs_encoding = false;
    bool needs_decoding = false;
};

struct ParsedURL {
    std::string scheme;
    std::string userinfo;
    std::string host;
    std::string port;
    std::string path;
    std::string query;
    std::string fragment;
    bool has_authority = false;
    bool has_query = false;
    bool has_fragment = false;
    bool host_was_bracketed = false;
    HostKind host_kind = HostKind::empty;
    bool valid = false;
    std::string error_message;
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

constexpr inline bool is_valid_unicode_scalar(uint32_t cp) noexcept {
    return cp <= 0x10FFFF && (cp < 0xD800 || cp > 0xDFFF);
}

std::vector<uint32_t> utf8_to_codepoints(const std::string& input);
std::string codepoints_to_utf8(const std::vector<uint32_t>& codepoints);
bool has_non_ascii(const std::string& input);
bool starts_with_xn_prefix(const std::string& label);

std::string punycode_encode_label_fallback(const std::string& label);
std::string punycode_decode_label_fallback(const std::string& label);
bool libidn2_backend_available() noexcept;
LabelBackend select_label_backend(
    BackendPreference preference = BackendPreference::automatic
);

ParsedDomain validate_and_parse_domain(
    const std::string& domain,
    const LabelBackend& backend,
    bool strict,
    DomainTransform transform = DomainTransform::none
);
bool looks_like_url_input(const std::string& input);

ParsedURL parse_url_string(const std::string& url);
std::string rebuild_url_with_host(const ParsedURL& parsed, const std::string& host);

class PunycodeService {
public:
    explicit PunycodeService(bool strict);
    PunycodeService(bool strict, const LabelBackend& backend);

    std::string encode_domain(const std::string& unicode_domain) const;
    std::string decode_domain(const std::string& punycode_domain) const;
    std::string encode_url(const std::string& url) const;
    std::string decode_url(const std::string& url) const;
    bool is_valid_domain(const std::string& domain) const;

private:
    enum class UrlTransform { encode, decode };

    std::string transform_domain(
        const std::string& domain,
        DomainTransform transform
    ) const;
    std::string transform_url(const std::string& url, UrlTransform transform) const;

    LabelBackend backend_;
    bool strict_;
};

}  // namespace punycoder

#endif
