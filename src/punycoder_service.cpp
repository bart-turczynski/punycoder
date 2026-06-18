#include "punycoder_core.h"

namespace punycoder {

namespace {

const std::string& resolved_label(
    const LabelInfo& label,
    DomainTransform transform
) {
    if (transform == DomainTransform::encode && label.needs_encoding &&
        !label.transformed.empty()) {
        return label.transformed;
    }

    if (transform == DomainTransform::decode && label.needs_decoding &&
        !label.transformed.empty()) {
        return label.transformed;
    }

    return label.value;
}

std::string materialize_domain(
    const ParsedDomain& parsed,
    DomainTransform transform
) {
    size_t total = parsed.has_trailing_dot ? 1 : 0;
    if (!parsed.labels.empty()) {
        total += parsed.labels.size() - 1;
    }
    for (const LabelInfo& label : parsed.labels) {
        total += resolved_label(label, transform).size();
    }

    std::string output;
    output.reserve(total);
    for (size_t i = 0; i < parsed.labels.size(); ++i) {
        if (i > 0) {
            output.push_back('.');
        }
        output += resolved_label(parsed.labels[i], transform);
    }
    if (parsed.has_trailing_dot) {
        output.push_back('.');
    }

    return output;
}

}  // namespace

PunycodeService::PunycodeService(bool strict)
    : PunycodeService(strict, true) {}

PunycodeService::PunycodeService(bool strict, bool verify_dns_length)
    : backend_(select_label_backend()),
      strict_(strict),
      verify_dns_length_(verify_dns_length) {}

PunycodeService::PunycodeService(bool strict, const LabelBackend& backend)
    : PunycodeService(strict, backend, true) {}

PunycodeService::PunycodeService(
    bool strict,
    const LabelBackend& backend,
    bool verify_dns_length
)
    : backend_(backend),
      strict_(strict),
      verify_dns_length_(verify_dns_length) {}

std::string PunycodeService::encode_domain(const std::string& unicode_domain) const {
    return transform_domain(unicode_domain, DomainTransform::encode);
}

std::string PunycodeService::decode_domain(const std::string& punycode_domain) const {
    return transform_domain(punycode_domain, DomainTransform::decode);
}

std::string PunycodeService::encode_url(const std::string& url) const {
    return transform_url(url, UrlTransform::encode);
}

std::string PunycodeService::decode_url(const std::string& url) const {
    return transform_url(url, UrlTransform::decode);
}

bool PunycodeService::is_valid_domain(const std::string& domain) const {
    try {
        validate_and_parse_domain(
            domain,
            backend_,
            strict_,
            verify_dns_length_,
            DomainTransform::none
        );
        return true;
    } catch (const std::exception&) {
        return false;
    }
}

std::string PunycodeService::transform_domain(
    const std::string& domain,
    DomainTransform transform
) const {
    ParsedDomain parsed = validate_and_parse_domain(
        domain,
        backend_,
        strict_,
        verify_dns_length_,
        transform
    );
    return materialize_domain(parsed, transform);
}

std::string PunycodeService::transform_url(
    const std::string& url,
    UrlTransform transform
) const {
    ParsedURL parsed = parse_url_string(url);
    if (!parsed.valid) {
        throw std::invalid_argument(parsed.error_message);
    }

    if (!parsed.has_authority || parsed.host.empty()) {
        return url;
    }

    if (parsed.host_kind == HostKind::ipv4 || parsed.host_kind == HostKind::ipv6) {
        return url;
    }

    std::string host;
    if (transform == UrlTransform::encode) {
        host = encode_domain(parsed.host);
    } else {
        host = decode_domain(parsed.host);
    }
    return rebuild_url_with_host(parsed, host);
}

}  // namespace punycoder
