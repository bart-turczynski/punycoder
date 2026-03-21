#include "punycoder_core.h"

namespace punycoder {

std::vector<uint32_t> utf8_to_codepoints(const std::string& input) {
    std::vector<uint32_t> codepoints;
    codepoints.reserve(input.size());

    size_t i = 0;
    while (i < input.size()) {
        unsigned char c = static_cast<unsigned char>(input[i]);

        if (c < 0x80) {
            codepoints.push_back(static_cast<uint32_t>(c));
            ++i;
            continue;
        }

        uint32_t cp = 0;
        size_t extra = 0;

        if ((c & 0xE0) == 0xC0) {
            cp = c & 0x1F;
            extra = 1;
        } else if ((c & 0xF0) == 0xE0) {
            cp = c & 0x0F;
            extra = 2;
        } else if ((c & 0xF8) == 0xF0) {
            cp = c & 0x07;
            extra = 3;
        } else {
            throw_error(ErrorCode::invalid_utf8_sequence);
        }

        if (i + extra >= input.size()) {
            throw_error(ErrorCode::truncated_utf8_sequence);
        }

        for (size_t j = 1; j <= extra; ++j) {
            unsigned char cc = static_cast<unsigned char>(input[i + j]);
            if ((cc & 0xC0) != 0x80) {
                throw_error(ErrorCode::invalid_utf8_continuation);
            }
            cp = (cp << 6) | (cc & 0x3F);
        }

        if ((extra == 1 && cp < 0x80) ||
            (extra == 2 && cp < 0x800) ||
            (extra == 3 && cp < 0x10000)) {
            throw_error(ErrorCode::overlong_utf8_sequence);
        }

        if (cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) {
            throw_error(ErrorCode::invalid_utf8_code_point);
        }

        codepoints.push_back(cp);
        i += extra + 1;
    }

    return codepoints;
}

std::string codepoints_to_utf8(const std::vector<uint32_t>& codepoints) {
    std::string output;

    for (uint32_t cp : codepoints) {
        if (cp <= 0x7F) {
            output.push_back(static_cast<char>(cp));
        } else if (cp <= 0x7FF) {
            output.push_back(static_cast<char>(0xC0 | ((cp >> 6) & 0x1F)));
            output.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else if (cp <= 0xFFFF) {
            output.push_back(static_cast<char>(0xE0 | ((cp >> 12) & 0x0F)));
            output.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            output.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else if (cp <= 0x10FFFF) {
            output.push_back(static_cast<char>(0xF0 | ((cp >> 18) & 0x07)));
            output.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
            output.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            output.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else {
            throw_error(ErrorCode::invalid_unicode_code_point);
        }
    }

    return output;
}

bool has_non_ascii(const std::string& input) {
    for (unsigned char c : input) {
        if (c > 0x7F) {
            return true;
        }
    }
    return false;
}

std::vector<std::string> split_on_dot(const std::string& domain) {
    std::vector<std::string> parts;
    size_t start = 0;

    for (size_t i = 0; i <= domain.size(); ++i) {
        if (i == domain.size() || domain[i] == '.') {
            parts.push_back(domain.substr(start, i - start));
            start = i + 1;
        }
    }

    return parts;
}

std::string join_with_dot(const std::vector<std::string>& labels) {
    if (labels.empty()) {
        return "";
    }

    size_t total = labels.size() - 1;
    for (const auto& label : labels) {
        total += label.size();
    }

    std::string output;
    output.reserve(total);
    output = labels[0];
    for (size_t i = 1; i < labels.size(); ++i) {
        output.push_back('.');
        output += labels[i];
    }

    return output;
}

}  // namespace punycoder
