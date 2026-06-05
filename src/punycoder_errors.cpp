#include "punycoder_core.h"

#include <stdexcept>

namespace punycoder {

namespace {

[[noreturn]] void unreachable_error_code(ErrorCode code) {
    throw std::logic_error(
        "punycoder: unhandled ErrorCode value " +
        std::to_string(static_cast<int>(code))
    );
}

std::string format_error(ErrorCode code, const std::string& detail) {
    switch (code) {
    case ErrorCode::invalid_punycode_digit:
        return "Invalid punycode digit";
    case ErrorCode::invalid_utf8_sequence:
        return "Invalid UTF-8 sequence";
    case ErrorCode::truncated_utf8_sequence:
        return "Truncated UTF-8 sequence";
    case ErrorCode::invalid_utf8_continuation:
        return "Invalid UTF-8 continuation byte";
    case ErrorCode::overlong_utf8_sequence:
        return "Overlong UTF-8 sequence";
    case ErrorCode::invalid_utf8_code_point:
        return "Invalid UTF-8 code point";
    case ErrorCode::invalid_unicode_code_point:
        return "Invalid Unicode code point";
    case ErrorCode::empty_domain_label:
        return "Domain label cannot be empty";
    case ErrorCode::invalid_punycode_label:
        return "Invalid punycode label";
    case ErrorCode::punycode_overflow:
        return "Punycode overflow";
    case ErrorCode::invalid_basic_code_point:
        return "Invalid basic code point in punycode";
    case ErrorCode::truncated_punycode_input:
        return "Truncated punycode input";
    case ErrorCode::decoded_code_point_out_of_range:
        return "Decoded code point out of range";
    case ErrorCode::domain_empty:
        return "Domain name cannot be empty";
    case ErrorCode::domain_too_long:
        return "Domain name too long (max 253 characters)";
    case ErrorCode::domain_empty_label:
        return "Domain contains empty label";
    case ErrorCode::domain_label_too_long:
        return "Domain label too long (max 63 characters)";
    case ErrorCode::domain_label_hyphen:
        return "Domain label cannot start or end with hyphen";
    case ErrorCode::ascii_domain_characters:
        return "ASCII domain labels may contain only letters, numbers and hyphens";
    case ErrorCode::encoded_label_too_long:
        return "Encoded punycode label exceeds 63 characters";
    case ErrorCode::label_length_limit:
        return "Domain label exceeds maximum supported length";
    case ErrorCode::invalid_ipv6_authority:
        return "Invalid IPv6 authority";
    case ErrorCode::invalid_authority:
        return "Invalid authority";
    case ErrorCode::empty_url:
        return "Empty URL";
    case ErrorCode::backend_failure:
        if (!detail.empty()) {
            return detail;
        }
        return "Backend failure";
    }

    unreachable_error_code(code);
}

}  // namespace

PunycoderError::PunycoderError(ErrorCode code, const std::string& message)
    : std::runtime_error(message), code_(code) {}

ErrorCode PunycoderError::code() const noexcept {
    return code_;
}

[[noreturn]] void throw_error(ErrorCode code) {
    throw PunycoderError(code, format_error(code, ""));
}

[[noreturn]] void throw_error(ErrorCode code, const std::string& detail) {
    throw PunycoderError(code, format_error(code, detail));
}

}  // namespace punycoder
