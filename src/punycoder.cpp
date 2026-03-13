#include <Rcpp.h>
#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

#ifdef PUNYCODER_USE_LIBIDN2
#include <idn2.h>
#endif

namespace {

// ============================================================
// Constants & Types
// ============================================================

constexpr uint32_t kBase = 36;
constexpr uint32_t kTmin = 1;
constexpr uint32_t kTmax = 26;
constexpr uint32_t kSkew = 38;
constexpr uint32_t kDamp = 700;
constexpr uint32_t kInitialBias = 72;
constexpr uint32_t kInitialN = 128;
constexpr char kDelimiter = '-';

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
    bool valid = false;
    std::string error_message;
};

// ============================================================
// Shared Helpers
// ============================================================

inline uint32_t compute_threshold(uint32_t k, uint32_t bias) {
    if (k <= bias) return kTmin;
    if (k >= bias + kTmax) return kTmax;
    return k - bias;
}

bool starts_with_xn_prefix(const std::string& label) {
    if (label.size() < 4) {
        return false;
    }

    return std::tolower(static_cast<unsigned char>(label[0])) == 'x' &&
           std::tolower(static_cast<unsigned char>(label[1])) == 'n' &&
           label[2] == '-' && label[3] == '-';
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
    // nocov start
    throw std::invalid_argument("Invalid punycode digit");
    // nocov end
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

// ============================================================
// UTF-8 Subsystem
// ============================================================

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
            throw std::invalid_argument("Invalid UTF-8 sequence");
        }

        if (i + extra >= input.size()) {
            throw std::invalid_argument("Truncated UTF-8 sequence");
        }

        for (size_t j = 1; j <= extra; ++j) {
            unsigned char cc = static_cast<unsigned char>(input[i + j]);
            if ((cc & 0xC0) != 0x80) {
                throw std::invalid_argument("Invalid UTF-8 continuation byte");
            }
            cp = (cp << 6) | (cc & 0x3F);
        }

        if ((extra == 1 && cp < 0x80) ||
            (extra == 2 && cp < 0x800) ||
            (extra == 3 && cp < 0x10000)) {
            throw std::invalid_argument("Overlong UTF-8 sequence");
        }

        if (cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) {
            throw std::invalid_argument("Invalid UTF-8 code point");
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
            // nocov start
            throw std::invalid_argument("Invalid Unicode code point");
            // nocov end
        }
    }

    return output;
}

bool has_non_ascii(const std::string& s) {
    for (unsigned char c : s) {
        if (c > 0x7F) {
            return true;
        }
    }
    return false;
}

// ============================================================
// String & Domain Utilities
// ============================================================

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
        // nocov start
        return "";
        // nocov end
    }

    size_t total = labels.size() - 1;  // dots
    for (const auto& l : labels) total += l.size();

    std::string out;
    out.reserve(total);
    out = labels[0];
    for (size_t i = 1; i < labels.size(); ++i) {
        out.push_back('.');
        out += labels[i];
    }

    return out;
}

// ============================================================
// RFC 3492 Punycode Core
// ============================================================

struct EncodingInput {
    std::vector<uint32_t> codepoints;
    bool needs_encoding;
};

EncodingInput prepare_encode_input(const std::string& label) {
    if (label.empty()) {
        // nocov start
        throw std::invalid_argument("Domain label cannot be empty");
        // nocov end
    }

    std::vector<uint32_t> cps = utf8_to_codepoints(label);
    bool needs = std::any_of(cps.begin(), cps.end(),
                             [](uint32_t cp) { return cp >= 0x80; });
    return {std::move(cps), needs};
}

#ifdef PUNYCODER_USE_LIBIDN2
std::string libidn2_error_message(int rc) {
    const char* error = idn2_strerror(rc);
    if (error == nullptr) {
        return "libidn2 returned unknown error";
    }
    return std::string(error);
}
#endif

std::string punycode_encode_label_fallback(const std::string& label) {
    EncodingInput ei = prepare_encode_input(label);

    if (!ei.needs_encoding) {
        return label;
    }

    const std::vector<uint32_t>& input = ei.codepoints;
    std::string output;
    size_t basic_count = 0;
    size_t handled = 0;

    for (uint32_t cp : input) {
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

    while (handled < input.size()) {
        uint32_t m = std::numeric_limits<uint32_t>::max();
        for (uint32_t cp : input) {
            if (cp >= n && cp < m) {
                m = cp;
            }
        }

        // nocov start
        if (m == std::numeric_limits<uint32_t>::max()) {
            throw std::overflow_error("Punycode overflow");
        }

        uint64_t span = static_cast<uint64_t>(m - n) * (handled + 1);
        if (span > std::numeric_limits<uint64_t>::max() - delta) {
            throw std::overflow_error("Punycode overflow");
        }
        // nocov end
        delta += span;
        n = m;

        for (uint32_t cp : input) {
            if (cp < n) {
                // nocov start
                if (delta == std::numeric_limits<uint64_t>::max()) {
                    throw std::overflow_error("Punycode overflow");
                }
                // nocov end
                ++delta;
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
        throw std::invalid_argument("Invalid punycode label");
    }

    std::vector<uint32_t> output;
    // Pre-allocate for expected output size. The O(n^2) insert pattern
    // below is bounded by DNS label limits (max 63 chars per label).
    output.reserve(input.size());
    size_t pos = input.find_last_of(kDelimiter);
    size_t index = 0;

    if (pos != std::string::npos) {
                for (size_t j = 0; j < pos; ++j) {
                    unsigned char c = static_cast<unsigned char>(input[j]);
                    if (c >= 0x80) {
                        // nocov start
                        throw std::invalid_argument("Invalid basic code point in punycode");
                        // nocov end
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
                throw std::invalid_argument("Truncated punycode input");
            }

            int digit = decode_digit(input[index++]);
            if (digit < 0) {
                throw std::invalid_argument("Invalid punycode digit");
            }

            // nocov start
            if (static_cast<uint64_t>(digit) >
                (std::numeric_limits<uint64_t>::max() - i) / w) {
                throw std::overflow_error("Punycode overflow");
            }
            // nocov end

            i += static_cast<uint64_t>(digit) * w;

            uint32_t t = compute_threshold(k, bias);

            if (static_cast<uint32_t>(digit) < t) {
                break;
            }

            uint64_t base_minus_t = kBase - t;
            // nocov start
            if (w > std::numeric_limits<uint64_t>::max() / base_minus_t) {
                throw std::overflow_error("Punycode overflow");
            }
            // nocov end
            w *= base_minus_t;
        }

        uint64_t out_len = output.size() + 1;
        bias = adapt(i - oldi, out_len, oldi == 0);

        uint64_t increment = i / out_len;
        // nocov start
        if (increment > std::numeric_limits<uint32_t>::max() - n) {
            throw std::overflow_error("Punycode overflow");
        }
        // nocov end
        n += static_cast<uint32_t>(increment);
        i %= out_len;

        // nocov start
        if (n > 0x10FFFF || (n >= 0xD800 && n <= 0xDFFF)) {
            throw std::invalid_argument("Decoded code point out of range");
        }
        // nocov end

        output.insert(output.begin() + static_cast<std::ptrdiff_t>(i), n);
        ++i;
    }

    return codepoints_to_utf8(output);
}

// ============================================================
// libidn2 Dual Backend
// ============================================================

#ifdef PUNYCODER_USE_LIBIDN2
std::string punycode_encode_label_libidn2(const std::string& label) {
    EncodingInput ei = prepare_encode_input(label);

    if (!ei.needs_encoding) {
        return label;
    }

    const std::vector<uint32_t>& input = ei.codepoints;
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
            // nocov start
            if (next_size <= buffer_size) {
                throw std::overflow_error("Punycode overflow");
            }
            // nocov end
            buffer_size = next_size;
            continue;
        }

        throw std::invalid_argument(libidn2_error_message(rc));
    }
}

std::string punycode_decode_label_libidn2(const std::string& label) {
    if (!starts_with_xn_prefix(label)) {
        return label;
    }

    std::string input = label.substr(4);
    if (input.empty()) {
        throw std::invalid_argument("Invalid punycode label");
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
            // nocov start
            if (next_size <= buffer_size) {
                throw std::overflow_error("Punycode overflow");
            }
            // nocov end
            buffer_size = next_size;
            continue;
        }

        throw std::invalid_argument(libidn2_error_message(rc));
    }
}
#endif

std::string punycode_encode_label(const std::string& label) {
#ifdef PUNYCODER_USE_LIBIDN2
    try {
        return punycode_encode_label_libidn2(label);
    } catch (const std::exception&) {
        return punycode_encode_label_fallback(label);
    }
#else
    return punycode_encode_label_fallback(label);
#endif
}

std::string punycode_decode_label(const std::string& label) {
#ifdef PUNYCODER_USE_LIBIDN2
    // Preserve RFC 3492 case behavior for labels with uppercase payload.
    std::string payload = starts_with_xn_prefix(label) ? label.substr(4) : std::string();
    bool has_uppercase_payload =
        std::any_of(payload.begin(), payload.end(), [](unsigned char c) {
            return std::isupper(c) != 0;
        });
    if (has_uppercase_payload) {
        return punycode_decode_label_fallback(label);
    }

    return punycode_decode_label_libidn2(label);
#else
    return punycode_decode_label_fallback(label);
#endif
}

// ============================================================
// Domain Validation & URL Detection
// ============================================================

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

struct ValidatedDomain {
    std::vector<std::string> labels;
    std::vector<std::vector<uint32_t>> label_codepoints;
    bool has_trailing_dot;
};

ValidatedDomain validate_and_parse_domain(const std::string& domain, bool strict) {
    if (domain.empty()) {
        throw std::invalid_argument("Domain name cannot be empty");
    }

    ValidatedDomain result;
    result.has_trailing_dot = !domain.empty() && domain.back() == '.';

    std::string core = domain;
    if (result.has_trailing_dot) {
        core.pop_back();
    }

    if (core.empty()) {
        throw std::invalid_argument("Domain name cannot be empty");
    }

    if (strict && core.size() > 253) {
        throw std::invalid_argument("Domain name too long (max 253 characters)");
    }

    result.labels = split_on_dot(core);
    result.label_codepoints.reserve(result.labels.size());

    for (const std::string& label : result.labels) {
        if (label.empty()) {
            throw std::invalid_argument("Domain contains empty label");
        }

        // Parse UTF-8 once and cache the codepoints
        result.label_codepoints.push_back(utf8_to_codepoints(label));

        if (strict && label.size() > 63) {
            throw std::invalid_argument("Domain label too long (max 63 characters)");
        }

        if (strict) {
            if (label.front() == '-' || label.back() == '-') {
                throw std::invalid_argument("Domain label cannot start or end with hyphen");
            }

            for (unsigned char c : label) {
                if (c < 0x80 && !std::isalnum(c) && c != '-') {
                    throw std::invalid_argument("ASCII domain labels may contain only letters, numbers and hyphens");
                }
            }
        }

        if (!has_non_ascii(label)) {
            if (starts_with_xn_prefix(label)) {
                std::string decoded = punycode_decode_label(label);
                // nocov start
                if (strict && decoded.empty()) {
                    throw std::invalid_argument("Invalid punycode label");
                }
                // nocov end
            }
        } else if (strict) {
            std::string encoded = punycode_encode_label(label);
            std::string payload = encoded.substr(4);
            // nocov start
            if (payload.size() > 63) {
                throw std::invalid_argument("Encoded punycode label exceeds 63 characters");
            }
            // nocov end
        }
    }

    return result;
}

void validate_domain_name(const std::string& domain, bool strict) {
    validate_and_parse_domain(domain, strict);
}

// ============================================================
// URL Parsing
// ============================================================

bool parse_authority(const std::string& authority, ParsedURL* parsed) {
    std::string host_port = authority;
    size_t at_pos = host_port.find_last_of('@');
    if (at_pos != std::string::npos) {
        parsed->userinfo = host_port.substr(0, at_pos);
        host_port = host_port.substr(at_pos + 1);
    }

    if (host_port.empty()) {
        parsed->host.clear();
        return true;
    }

    if (host_port[0] == '[') {
        size_t close = host_port.find(']');
        if (close == std::string::npos) {
            parsed->error_message = "Invalid IPv6 authority";
            return false;
        }

        parsed->host_was_bracketed = true;
        parsed->host = host_port.substr(1, close - 1);
        if (close + 1 < host_port.size()) {
            if (host_port[close + 1] != ':') {
                parsed->error_message = "Invalid authority";
                return false;
            }
            parsed->port = host_port.substr(close + 2);
        }
    } else {
        size_t colon = host_port.find_last_of(':');
        if (colon != std::string::npos &&
            host_port.find(':') == colon) {
            std::string maybe_port = host_port.substr(colon + 1);
            if (!maybe_port.empty() &&
                std::all_of(maybe_port.begin(), maybe_port.end(),
                            [](char c) { return std::isdigit(static_cast<unsigned char>(c)); })) {
                parsed->host = host_port.substr(0, colon);
                parsed->port = maybe_port;
            } else {
                parsed->host = host_port;
            }
        } else {
            parsed->host = host_port;
        }
    }

    return true;
}

ParsedURL parse_url_string(const std::string& url) {
    ParsedURL parsed;
    if (url.empty()) {
        parsed.error_message = "Empty URL";
        return parsed;
    }

    // Hand-coded RFC 3986 URI decomposition (replaces std::regex for speed).
    // Grammar: ^(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?
    size_t pos = 0;

    // 1. Scheme: everything before ':' that doesn't contain '/', '?', or '#'
    size_t scheme_end = url.find_first_of(":/?#");
    if (scheme_end != std::string::npos && url[scheme_end] == ':') {
        parsed.scheme = url.substr(0, scheme_end);
        pos = scheme_end + 1;
    }

    // 2. Authority: if next chars are "//"
    if (pos + 1 < url.size() && url[pos] == '/' && url[pos + 1] == '/') {
        parsed.has_authority = true;
        pos += 2;
        size_t auth_end = url.find_first_of("/?#", pos);
        if (auth_end == std::string::npos) auth_end = url.size();
        if (!parse_authority(url.substr(pos, auth_end - pos), &parsed)) {
            return parsed;
        }
        pos = auth_end;
    }

    // 3. Path: up to '?' or '#'
    size_t path_end = url.find_first_of("?#", pos);
    if (path_end == std::string::npos) path_end = url.size();
    parsed.path = url.substr(pos, path_end - pos);
    pos = path_end;

    // 4. Query: after '?' up to '#'
    if (pos < url.size() && url[pos] == '?') {
        parsed.has_query = true;
        ++pos;
        size_t query_end = url.find('#', pos);
        if (query_end == std::string::npos) query_end = url.size();
        parsed.query = url.substr(pos, query_end - pos);
        pos = query_end;
    }

    // 5. Fragment: after '#' to end
    if (pos < url.size() && url[pos] == '#') {
        parsed.has_fragment = true;
        parsed.fragment = url.substr(pos + 1);
    }

    parsed.valid = true;
    return parsed;
}

std::string rebuild_url_with_host(const ParsedURL& parsed, const std::string& host) {
    std::string result;

    if (!parsed.scheme.empty()) {
        result += parsed.scheme;
        result.push_back(':');
    }

    if (parsed.has_authority) {
        result += "//";
        if (!parsed.userinfo.empty()) {
            result += parsed.userinfo;
            result.push_back('@');
        }

        bool needs_brackets = parsed.host_was_bracketed;

        if (needs_brackets) {
            result.push_back('[');
            result += host;
            result.push_back(']');
        } else {
            result += host;
        }

        if (!parsed.port.empty()) {
            result.push_back(':');
            result += parsed.port;
        }
    }

    result += parsed.path;

    if (parsed.has_query) {
        result.push_back('?');
        result += parsed.query;
    }

    if (parsed.has_fragment) {
        result.push_back('#');
        result += parsed.fragment;
    }

    return result;
}

// ============================================================
// PunycodeProcessor Class
// ============================================================

class PunycodeProcessor {
public:
    explicit PunycodeProcessor(bool strict = true) : strict_validation_(strict) {}

    std::string encode_domain(const std::string& unicode_domain) const {
        validate_domain_name(unicode_domain, strict_validation_);

        bool trailing_dot =
            !unicode_domain.empty() && unicode_domain.back() == '.';
        std::string core = trailing_dot
            ? unicode_domain.substr(0, unicode_domain.size() - 1)
            : unicode_domain;

        std::vector<std::string> labels = split_on_dot(core);
        for (std::string& label : labels) {
            label = punycode_encode_label(label);
        }

        std::string encoded = join_with_dot(labels);
        if (trailing_dot) {
            encoded.push_back('.');
        }
        return encoded;
    }

    std::string decode_domain(const std::string& punycode_domain) const {
        validate_domain_name(punycode_domain, strict_validation_);

        bool trailing_dot =
            !punycode_domain.empty() && punycode_domain.back() == '.';
        std::string core = trailing_dot
            ? punycode_domain.substr(0, punycode_domain.size() - 1)
            : punycode_domain;

        std::vector<std::string> labels = split_on_dot(core);
        for (std::string& label : labels) {
            label = punycode_decode_label(label);
        }

        std::string decoded = join_with_dot(labels);
        if (trailing_dot) {
            decoded.push_back('.');
        }
        return decoded;
    }

    bool is_valid_domain(const std::string& domain) const {
        try {
            validate_domain_name(domain, strict_validation_);
            return true;
        } catch (const std::exception&) {
            return false;
        }
    }

private:
    bool strict_validation_;
};

}  // namespace

// ============================================================
// Public R Interface
// ============================================================

// [[Rcpp::export]]
Rcpp::CharacterVector puny_encode_cpp(Rcpp::CharacterVector domains, bool strict = true) {
    PunycodeProcessor processor(strict);
    Rcpp::CharacterVector results(domains.size());

    for (R_xlen_t i = 0; i < domains.size(); ++i) {
        try {
            if (Rcpp::CharacterVector::is_na(domains[i])) {
                results[i] = NA_STRING;
            } else {
                std::string domain = Rcpp::as<std::string>(domains[i]);
                if (looks_like_url_input(domain)) {
                    throw std::invalid_argument(
                        "ASCII domain labels may contain only letters, numbers and hyphens"
                    );
                }
                results[i] = processor.encode_domain(domain);
            }
        } catch (const std::exception& e) {
            if (strict) {
                Rcpp::stop("Error encoding domain: %s", e.what());
            }
            results[i] = NA_STRING;
        }
    }

    return results;
}

// [[Rcpp::export]]
Rcpp::CharacterVector puny_decode_cpp(Rcpp::CharacterVector domains, bool strict = true) {
    PunycodeProcessor processor(strict);
    Rcpp::CharacterVector results(domains.size());

    for (R_xlen_t i = 0; i < domains.size(); ++i) {
        try {
            if (Rcpp::CharacterVector::is_na(domains[i])) {
                results[i] = NA_STRING;
            } else {
                std::string domain = Rcpp::as<std::string>(domains[i]);
                if (looks_like_url_input(domain)) {
                    throw std::invalid_argument(
                        "ASCII domain labels may contain only letters, numbers and hyphens"
                    );
                }
                results[i] = processor.decode_domain(domain);
            }
        } catch (const std::exception& e) {
            if (strict) {
                Rcpp::stop("Error decoding domain: %s", e.what());
            }
            results[i] = NA_STRING;
        }
    }

    return results;
}

// [[Rcpp::export]]
Rcpp::CharacterVector url_encode_cpp(Rcpp::CharacterVector urls, bool strict = true) {
    PunycodeProcessor processor(strict);
    Rcpp::CharacterVector results(urls.size());

    for (R_xlen_t i = 0; i < urls.size(); ++i) {
        try {
            if (Rcpp::CharacterVector::is_na(urls[i])) {
                results[i] = NA_STRING;
                continue;
            }

            std::string url = Rcpp::as<std::string>(urls[i]);
            ParsedURL parsed = parse_url_string(url);
            if (!parsed.valid) {
                if (strict) {
                    Rcpp::stop("Error encoding URL: %s", parsed.error_message.c_str());
                }
                results[i] = NA_STRING;
                continue;
            }

            if (!parsed.has_authority || parsed.host.empty()) {
                results[i] = url;
                continue;
            }

            std::string encoded_host = processor.encode_domain(parsed.host);
            results[i] = rebuild_url_with_host(parsed, encoded_host);
        } catch (const std::exception& e) {
            if (strict) {
                Rcpp::stop("Error encoding URL: %s", e.what());
            }
            results[i] = NA_STRING;
        }
    }

    return results;
}

// [[Rcpp::export]]
Rcpp::CharacterVector url_decode_cpp(Rcpp::CharacterVector urls, bool strict = true) {
    PunycodeProcessor processor(strict);
    Rcpp::CharacterVector results(urls.size());

    for (R_xlen_t i = 0; i < urls.size(); ++i) {
        try {
            if (Rcpp::CharacterVector::is_na(urls[i])) {
                results[i] = NA_STRING;
                continue;
            }

            std::string url = Rcpp::as<std::string>(urls[i]);
            ParsedURL parsed = parse_url_string(url);
            if (!parsed.valid) {
                if (strict) {
                    Rcpp::stop("Error decoding URL: %s", parsed.error_message.c_str());
                }
                results[i] = NA_STRING;
                continue;
            }

            if (!parsed.has_authority || parsed.host.empty()) {
                results[i] = url;
                continue;
            }

            std::string decoded_host = processor.decode_domain(parsed.host);
            results[i] = rebuild_url_with_host(parsed, decoded_host);
        } catch (const std::exception& e) {
            if (strict) {
                Rcpp::stop("Error decoding URL: %s", e.what());
            }
            results[i] = NA_STRING;
        }
    }

    return results;
}

// [[Rcpp::export]]
Rcpp::List parse_url_cpp(Rcpp::CharacterVector urls, bool encode_domains = false) {
    R_xlen_t n = urls.size();
    Rcpp::CharacterVector scheme(n, NA_STRING);
    Rcpp::CharacterVector domain(n, NA_STRING);
    Rcpp::IntegerVector port(n, NA_INTEGER);
    Rcpp::CharacterVector path(n, NA_STRING);
    Rcpp::CharacterVector query(n, NA_STRING);
    Rcpp::CharacterVector fragment(n, NA_STRING);
    PunycodeProcessor processor(false);

    for (R_xlen_t i = 0; i < n; ++i) {
        if (Rcpp::CharacterVector::is_na(urls[i])) {
            continue;
        }

        std::string url = Rcpp::as<std::string>(urls[i]);
        ParsedURL parsed = parse_url_string(url);
        if (!parsed.valid) {
            continue;
        }

        if (!parsed.scheme.empty()) {
            scheme[i] = parsed.scheme;
        }

        if (!parsed.path.empty()) {
            path[i] = parsed.path;
        } else {
            path[i] = "";
        }

        if (parsed.has_query) {
            query[i] = parsed.query;
        }

        if (parsed.has_fragment) {
            fragment[i] = parsed.fragment;
        }

        if (!parsed.host.empty()) {
            if (encode_domains) {
                try {
                    domain[i] = processor.encode_domain(parsed.host);
                } catch (const std::exception&) {
                    domain[i] = NA_STRING;
                }
            } else {
                domain[i] = parsed.host;
            }
        }

        if (!parsed.port.empty()) {
            char* end_ptr = nullptr;
            long parsed_port = std::strtol(parsed.port.c_str(), &end_ptr, 10);
            if (end_ptr != nullptr &&
                *end_ptr == '\0' &&
                parsed_port >= 0 &&
                parsed_port <= std::numeric_limits<int>::max()) {
                port[i] = static_cast<int>(parsed_port);
            }
        }
    }

    return Rcpp::List::create(
        Rcpp::Named("scheme") = scheme,
        Rcpp::Named("domain") = domain,
        Rcpp::Named("port") = port,
        Rcpp::Named("path") = path,
        Rcpp::Named("query") = query,
        Rcpp::Named("fragment") = fragment
    );
}

// [[Rcpp::export]]
Rcpp::List validate_domain_cpp(Rcpp::CharacterVector domains, bool strict = true) {
    R_xlen_t n = domains.size();
    Rcpp::LogicalVector valid(n);
    Rcpp::List errors(n);

    for (R_xlen_t i = 0; i < n; ++i) {
        if (Rcpp::CharacterVector::is_na(domains[i])) {
            valid[i] = false;
            errors[i] = Rcpp::CharacterVector::create("Domain is NA");
            continue;
        }

        std::string domain = Rcpp::as<std::string>(domains[i]);

        try {
            validate_domain_name(domain, strict);
            valid[i] = true;
            errors[i] = Rcpp::CharacterVector::create();
        } catch (const std::exception& e) {
            valid[i] = false;
            errors[i] = Rcpp::CharacterVector::create(e.what());
        }
    }

    return Rcpp::List::create(
        Rcpp::Named("domains") = domains,
        Rcpp::Named("valid") = valid,
        Rcpp::Named("errors") = errors
    );
}
