#include "punycoder_core.h"

#include <algorithm>
#include <cctype>

namespace punycoder {

bool looks_like_url_input(const std::string& input) {
    if (input.find("://") != std::string::npos) {
        return true;
    }

    if (input.rfind("//", 0) == 0) {
        return true;
    }

    if (input.find('/') != std::string::npos ||
        input.find('?') != std::string::npos ||
        input.find('#') != std::string::npos ||
        input.find('@') != std::string::npos) {
        return true;
    }

    size_t colon_pos = input.find(':');
    if (colon_pos != std::string::npos && colon_pos > 0 &&
        std::isalpha(static_cast<unsigned char>(input[0])) != 0) {
        bool scheme_like = std::all_of(
            input.begin() + 1,
            input.begin() + colon_pos,
            [](char c) {
                unsigned char uc = static_cast<unsigned char>(c);
                return std::isalnum(uc) != 0 || c == '+' || c == '-' || c == '.';
            }
        );
        if (scheme_like) {
            return true;
        }
    }

    return false;
}

ParsedDomain validate_and_parse_domain(
    const std::string& domain,
    const LabelBackend& backend,
    bool strict
) {
    if (domain.empty()) {
        throw_error(ErrorCode::domain_empty);
    }

    ParsedDomain result;
    result.has_trailing_dot = !domain.empty() && domain.back() == '.';

    std::string core = domain;
    if (result.has_trailing_dot) {
        core.pop_back();
    }

    if (core.empty()) {
        throw_error(ErrorCode::domain_empty);
    }

    if (strict && core.size() > 253) {
        throw_error(ErrorCode::domain_too_long);
    }

    result.labels = split_on_dot(core);
    for (const std::string& label : result.labels) {
        if (label.empty()) {
            throw_error(ErrorCode::domain_empty_label);
        }

        utf8_to_codepoints(label);

        if (strict && label.size() > 63) {
            throw_error(ErrorCode::domain_label_too_long);
        }

        if (strict) {
            if (label.front() == '-' || label.back() == '-') {
                throw_error(ErrorCode::domain_label_hyphen);
            }

            for (unsigned char c : label) {
                if (c < 0x80 && !std::isalnum(c) && c != '-') {
                    throw_error(ErrorCode::ascii_domain_characters);
                }
            }
        }

        if (!has_non_ascii(label)) {
            if (starts_with_xn_prefix(label)) {
                std::string decoded = backend.decode(label);
                if (strict && decoded.empty()) {
                    throw_error(ErrorCode::invalid_punycode_label);
                }
            }
        } else if (strict) {
            std::string encoded = backend.encode(label);
            std::string payload = encoded.substr(4);
            if (payload.size() > 63) {
                throw_error(ErrorCode::encoded_label_too_long);
            }
        }
    }

    return result;
}

}  // namespace punycoder
