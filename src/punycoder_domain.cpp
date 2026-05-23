#include "punycoder_core.h"

#include <algorithm>
#include <cctype>
#include <utility>

namespace punycoder {

namespace {

bool is_valid_ascii_domain_char(unsigned char c) {
    return std::isalnum(c) != 0 || c == '-';
}

void validate_encoded_label_length(const std::string& encoded) {
    size_t payload_size = encoded.size();
    if (starts_with_xn_prefix(encoded)) {
        payload_size -= 4;
    }
    if (payload_size > 63) {
        throw_error(ErrorCode::encoded_label_too_long);
    }
}

LabelInfo classify_label(const std::string& label, bool strict) {
    if (label.empty()) {
        throw_error(ErrorCode::domain_empty_label);
    }

    LabelInfo info;
    info.value = label;
    info.has_xn_prefix = starts_with_xn_prefix(label);

    if (strict) {
        if (label.size() > 63) {
            throw_error(ErrorCode::domain_label_too_long);
        }
        if (label.front() == '-' || label.back() == '-') {
            throw_error(ErrorCode::domain_label_hyphen);
        }
    }

    for (unsigned char c : label) {
        if (c >= 0x80) {
            info.is_ascii = false;
            continue;
        }
        if (strict && !is_valid_ascii_domain_char(c)) {
            throw_error(ErrorCode::ascii_domain_characters);
        }
    }

    info.needs_encoding = !info.is_ascii;
    info.needs_decoding = info.is_ascii && info.has_xn_prefix;

    return info;
}

void plan_label_transform(
    LabelInfo* label,
    const LabelBackend& backend,
    bool strict,
    DomainTransform transform
) {
    if (label->needs_decoding) {
        std::string decoded = backend.decode(label->value);
        if (strict && decoded.empty()) {
            throw_error(ErrorCode::invalid_punycode_label);
        }
        if (transform == DomainTransform::decode) {
            label->transformed = std::move(decoded);
        }
        return;
    }

    if (!label->needs_encoding) {
        return;
    }

    if (transform != DomainTransform::encode && !strict) {
        // The backend.encode call below would normally walk the UTF-8; on
        // this branch it doesn't run, so validate directly to preserve the
        // contract that any non-ASCII label is checked for well-formed UTF-8.
        utf8_to_codepoints(label->value);
        return;
    }

    std::string encoded = backend.encode(label->value);
    if (strict) {
        validate_encoded_label_length(encoded);
    }
    if (transform == DomainTransform::encode) {
        label->transformed = std::move(encoded);
    }
}

}  // namespace

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
    bool strict,
    DomainTransform transform
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

    std::vector<std::string> raw_labels = split_on_dot(core);
    result.labels.reserve(raw_labels.size());
    for (const std::string& raw_label : raw_labels) {
        LabelInfo label = classify_label(raw_label, strict);
        plan_label_transform(&label, backend, strict, transform);
        result.labels.push_back(std::move(label));
    }

    return result;
}

}  // namespace punycoder
