#include "punycoder_core.h"

#include <algorithm>
#include <cctype>

namespace punycoder {

namespace {

bool is_hex_digit(char c) {
    unsigned char uc = static_cast<unsigned char>(c);
    return std::isxdigit(uc) != 0;
}

bool is_ipv4_address(const std::string& host) {
    int octets = 0;
    size_t start = 0;

    for (size_t i = 0; i <= host.size(); ++i) {
        if (i != host.size() && host[i] != '.') {
            continue;
        }

        if (start == i) {
            return false;
        }

        int value = 0;
        for (size_t j = start; j < i; ++j) {
            unsigned char c = static_cast<unsigned char>(host[j]);
            if (std::isdigit(c) == 0) {
                return false;
            }
            value = (value * 10) + (c - '0');
            if (value > 255) {
                return false;
            }
        }

        ++octets;
        start = i + 1;
    }

    return octets == 4;
}

bool parse_ipv6_sequence(
    const std::string& input,
    bool allow_ipv4_tail,
    int* groups
) {
    *groups = 0;
    if (input.empty()) {
        return true;
    }

    size_t start = 0;
    for (;;) {
        size_t end = input.find(':', start);
        std::string token = input.substr(
            start,
            end == std::string::npos ? std::string::npos : end - start
        );
        if (token.empty()) {
            return false;
        }

        if (end == std::string::npos && allow_ipv4_tail &&
            token.find('.') != std::string::npos) {
            if (!is_ipv4_address(token)) {
                return false;
            }
            *groups += 2;
            return true;
        }

        if (token.size() > 4) {
            return false;
        }
        for (char c : token) {
            if (!is_hex_digit(c)) {
                return false;
            }
        }
        ++(*groups);

        if (end == std::string::npos) {
            return true;
        }

        start = end + 1;
    }
}

bool is_ipv6_address(const std::string& host) {
    if (host.empty()) {
        return false;
    }

    size_t double_colon = host.find("::");
    if (double_colon == std::string::npos) {
        int groups = 0;
        return parse_ipv6_sequence(host, true, &groups) && groups == 8;
    }

    if (host.find("::", double_colon + 2) != std::string::npos) {
        return false;
    }

    int left_groups = 0;
    int right_groups = 0;
    if (!parse_ipv6_sequence(host.substr(0, double_colon), false, &left_groups)) {
        return false;
    }
    if (!parse_ipv6_sequence(host.substr(double_colon + 2), true, &right_groups)) {
        return false;
    }

    return left_groups + right_groups < 8;
}

bool parse_authority(const std::string& authority, ParsedURL* parsed) {
    std::string host_port = authority;
    size_t at_pos = host_port.find_last_of('@');
    if (at_pos != std::string::npos) {
        parsed->userinfo = host_port.substr(0, at_pos);
        host_port = host_port.substr(at_pos + 1);
    }

    if (host_port.empty()) {
        parsed->host.clear();
        parsed->host_kind = HostKind::empty;
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
        if (!is_ipv6_address(parsed->host)) {
            parsed->error_message = "Invalid IPv6 authority";
            return false;
        }
        parsed->host_kind = HostKind::ipv6;
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
                std::all_of(maybe_port.begin(), maybe_port.end(), [](char c) {
                    return std::isdigit(static_cast<unsigned char>(c)) != 0;
                })) {
                parsed->host = host_port.substr(0, colon);
                parsed->port = maybe_port;
            } else {
                parsed->host = host_port;
            }
        } else {
            parsed->host = host_port;
        }

        if (parsed->host.empty()) {
            parsed->host_kind = HostKind::empty;
        } else if (is_ipv4_address(parsed->host)) {
            parsed->host_kind = HostKind::ipv4;
        } else {
            parsed->host_kind = HostKind::dns;
        }
    }

    return true;
}

}  // namespace

ParsedURL parse_url_string(const std::string& url) {
    ParsedURL parsed;
    if (url.empty()) {
        parsed.error_message = "Empty URL";
        return parsed;
    }

    size_t pos = 0;
    size_t scheme_end = url.find_first_of(":/?#");
    if (scheme_end != std::string::npos && url[scheme_end] == ':') {
        parsed.scheme = url.substr(0, scheme_end);
        pos = scheme_end + 1;
    }

    if (pos + 1 < url.size() && url[pos] == '/' && url[pos + 1] == '/') {
        parsed.has_authority = true;
        pos += 2;
        size_t auth_end = url.find_first_of("/?#", pos);
        if (auth_end == std::string::npos) {
            auth_end = url.size();
        }
        if (!parse_authority(url.substr(pos, auth_end - pos), &parsed)) {
            return parsed;
        }
        pos = auth_end;
    }

    size_t path_end = url.find_first_of("?#", pos);
    if (path_end == std::string::npos) {
        path_end = url.size();
    }
    parsed.path = url.substr(pos, path_end - pos);
    pos = path_end;

    if (pos < url.size() && url[pos] == '?') {
        parsed.has_query = true;
        ++pos;
        size_t query_end = url.find('#', pos);
        if (query_end == std::string::npos) {
            query_end = url.size();
        }
        parsed.query = url.substr(pos, query_end - pos);
        pos = query_end;
    }

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

        if (parsed.host_was_bracketed) {
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

}  // namespace punycoder
