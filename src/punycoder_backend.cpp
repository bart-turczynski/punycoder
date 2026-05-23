#include "punycoder_core.h"

#include <algorithm>
#include <cctype>
#include <vector>

#ifdef PUNYCODER_USE_LIBIDN2
#include <idn2.h>
#endif

namespace punycoder {

namespace {

#ifdef PUNYCODER_USE_LIBIDN2
std::string libidn2_error_message(int rc) {
    const char* error = idn2_strerror(rc);
    if (error == nullptr) {
        return "libidn2 returned unknown error";
    }
    return std::string(error);
}

std::string encode_label_libidn2(const std::string& label) {
    if (!has_non_ascii(label)) {
        return label;
    }

    std::vector<uint32_t> input = utf8_to_codepoints(label);
    size_t buffer_size = std::max<size_t>(32, (input.size() * 5) + 16);
    for (;;) {
        std::vector<char> output(buffer_size);
        size_t output_length = buffer_size;
        int rc = idn2_punycode_encode(
            input.data(),
            input.size(),
            output.data(),
            &output_length
        );

        if (rc == IDN2_OK) {
            return "xn--" + std::string(output.data(), output_length);
        }
        if (rc == IDN2_PUNYCODE_BIG_OUTPUT) {
            size_t next_size = std::max(buffer_size * 2, output_length + 1);
            if (next_size <= buffer_size) {
                throw_error(ErrorCode::punycode_overflow);
            }
            buffer_size = next_size;
            continue;
        }

        throw_error(ErrorCode::backend_failure, libidn2_error_message(rc));
    }
}

std::string decode_label_libidn2(const std::string& label) {
    if (!starts_with_xn_prefix(label)) {
        return label;
    }

    std::string input = label.substr(4);
    if (input.empty()) {
        throw_error(ErrorCode::invalid_punycode_label);
    }

    size_t buffer_size = std::max<size_t>(32, input.size() + 16);
    for (;;) {
        std::vector<uint32_t> output(buffer_size);
        size_t output_length = buffer_size;
        int rc = idn2_punycode_decode(
            input.c_str(),
            input.size(),
            output.data(),
            &output_length
        );

        if (rc == IDN2_OK) {
            output.resize(output_length);
            return codepoints_to_utf8(output);
        }
        if (rc == IDN2_PUNYCODE_BIG_OUTPUT) {
            size_t next_size = std::max(buffer_size * 2, output_length + 1);
            if (next_size <= buffer_size) {
                throw_error(ErrorCode::punycode_overflow);
            }
            buffer_size = next_size;
            continue;
        }

        throw_error(ErrorCode::backend_failure, libidn2_error_message(rc));
    }
}

bool has_uppercase_payload(const std::string& label) {
    std::string payload = starts_with_xn_prefix(label) ? label.substr(4) : "";
    return std::any_of(payload.begin(), payload.end(), [](unsigned char c) {
        return std::isupper(c) != 0;
    });
}

std::string default_encode_label(const std::string& label) {
    try {
        return encode_label_libidn2(label);
    } catch (const PunycoderError&) {
        // Only fall back on deterministic Punycode-level errors; let
        // std::bad_alloc and other genuine failures propagate.
        return punycode_encode_label_fallback(label);
    }
}

std::string default_decode_label(const std::string& label) {
    if (has_uppercase_payload(label)) {
        return punycode_decode_label_fallback(label);
    }

    try {
        return decode_label_libidn2(label);
    } catch (const PunycoderError&) {
        return punycode_decode_label_fallback(label);
    }
}
#endif

std::string fallback_encode_label(const std::string& label) {
    return punycode_encode_label_fallback(label);
}

std::string fallback_decode_label(const std::string& label) {
    return punycode_decode_label_fallback(label);
}

}  // namespace

bool libidn2_backend_available() noexcept {
#ifdef PUNYCODER_USE_LIBIDN2
    return true;
#else
    return false;
#endif
}

LabelBackend select_label_backend(BackendPreference preference) {
    if (preference == BackendPreference::fallback) {
        return {&fallback_encode_label, &fallback_decode_label, "fallback"};
    }

#ifdef PUNYCODER_USE_LIBIDN2
    if (preference == BackendPreference::libidn2) {
        return {&encode_label_libidn2, &decode_label_libidn2, "libidn2"};
    }
    return {&default_encode_label, &default_decode_label, "libidn2+fallback"};
#else
    (void) preference;
    return {&fallback_encode_label, &fallback_decode_label, "fallback"};
#endif
}

}  // namespace punycoder
