#include <Rcpp.h>

#include <cstdlib>
#include <limits>
#include <stdexcept>
#include <string>

#include "punycoder_core.h"
#include "punycoder_normalize.h"
#include "unicode_tables_16_0_0.h"

namespace {

template <typename Fn>
Rcpp::CharacterVector transform_strings(
    const Rcpp::CharacterVector& input,
    bool strict,
    const char* error_prefix,
    Fn&& fn
) {
    Rcpp::CharacterVector output(input.size());

    for (R_xlen_t i = 0; i < input.size(); ++i) {
        try {
            if (Rcpp::CharacterVector::is_na(input[i])) {
                output[i] = NA_STRING;
                continue;
            }

            output[i] = fn(Rcpp::as<std::string>(input[i]));
        } catch (const std::exception& e) {
            if (strict) {
                Rcpp::stop("%s: %s", error_prefix, e.what());
            }
            output[i] = NA_STRING;
        }
    }

    return output;
}

std::string apply_backend_mode(
    const punycoder::PunycodeService& service,
    const std::string& mode,
    const std::string& value
) {
    if (mode == "encode_domain") {
        return service.encode_domain(value);
    }
    if (mode == "decode_domain") {
        return service.decode_domain(value);
    }
    if (mode == "encode_url") {
        return service.encode_url(value);
    }
    if (mode == "decode_url") {
        return service.decode_url(value);
    }

    throw std::invalid_argument("Unknown backend comparison mode");
}

std::string safe_backend_mode(
    const punycoder::PunycodeService& service,
    const std::string& mode,
    const std::string& value
) {
    try {
        return apply_backend_mode(service, mode, value);
    } catch (const std::exception& e) {
        return std::string("__ERROR__: ") + e.what();
    }
}

}  // namespace

// [[Rcpp::export]]
Rcpp::CharacterVector puny_encode_cpp(Rcpp::CharacterVector domains, bool strict = true) {
    punycoder::PunycodeService service(strict, false);
    return transform_strings(
        domains,
        strict,
        "Error encoding domain",
        [&](const std::string& domain) {
            if (punycoder::looks_like_url_input(domain)) {
                punycoder::throw_error(punycoder::ErrorCode::ascii_domain_characters);
            }
            return service.encode_domain(domain);
        }
    );
}

// [[Rcpp::export]]
Rcpp::CharacterVector puny_decode_cpp(Rcpp::CharacterVector domains, bool strict = true) {
    punycoder::PunycodeService service(strict, false);
    return transform_strings(
        domains,
        strict,
        "Error decoding domain",
        [&](const std::string& domain) {
            if (punycoder::looks_like_url_input(domain)) {
                punycoder::throw_error(punycoder::ErrorCode::ascii_domain_characters);
            }
            return service.decode_domain(domain);
        }
    );
}

// [[Rcpp::export]]
Rcpp::CharacterVector url_encode_cpp(Rcpp::CharacterVector urls, bool strict = true) {
    punycoder::PunycodeService service(strict);
    return transform_strings(
        urls,
        strict,
        "Error encoding URL",
        [&](const std::string& url) {
            return service.encode_url(url);
        }
    );
}

// [[Rcpp::export]]
Rcpp::CharacterVector url_decode_cpp(Rcpp::CharacterVector urls, bool strict = true) {
    punycoder::PunycodeService service(strict);
    return transform_strings(
        urls,
        strict,
        "Error decoding URL",
        [&](const std::string& url) {
            return service.decode_url(url);
        }
    );
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
    punycoder::PunycodeService service(false);

    for (R_xlen_t i = 0; i < n; ++i) {
        if (Rcpp::CharacterVector::is_na(urls[i])) {
            continue;
        }

        std::string url = Rcpp::as<std::string>(urls[i]);
        punycoder::ParsedURL parsed = punycoder::parse_url_string(url);
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
            if (encode_domains && parsed.host_kind == punycoder::HostKind::dns) {
                try {
                    domain[i] = service.encode_domain(parsed.host);
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
    Rcpp::List error_codes(n);
    punycoder::LabelBackend backend = punycoder::select_label_backend();

    for (R_xlen_t i = 0; i < n; ++i) {
        if (Rcpp::CharacterVector::is_na(domains[i])) {
            valid[i] = false;
            errors[i] = Rcpp::CharacterVector::create("Domain is NA");
            error_codes[i] = Rcpp::CharacterVector::create("domain_na");
            continue;
        }

        std::string domain = Rcpp::as<std::string>(domains[i]);

        try {
            punycoder::validate_and_parse_domain(
                domain,
                backend,
                strict,
                true,
                punycoder::DomainTransform::none
            );
            valid[i] = true;
            errors[i] = Rcpp::CharacterVector::create();
            error_codes[i] = Rcpp::CharacterVector::create();
        } catch (const punycoder::PunycoderError& e) {
            valid[i] = false;
            errors[i] = Rcpp::CharacterVector::create(e.what());
            error_codes[i] = Rcpp::CharacterVector::create(
                punycoder::error_code_name(e.code())
            );
        } catch (const std::exception& e) {
            valid[i] = false;
            errors[i] = Rcpp::CharacterVector::create(e.what());
            error_codes[i] = Rcpp::CharacterVector::create("unknown_error");
        }
    }

    return Rcpp::List::create(
        Rcpp::Named("domains") = domains,
        Rcpp::Named("valid") = valid,
        Rcpp::Named("errors") = errors,
        Rcpp::Named("error_codes") = error_codes
    );
}

// [[Rcpp::export]]
Rcpp::List backend_info_cpp() {
    punycoder::LabelBackend backend = punycoder::select_label_backend();

    return Rcpp::List::create(
        Rcpp::Named("automatic") = backend.name,
        Rcpp::Named("has_libidn2") = punycoder::libidn2_backend_available()
    );
}

// [[Rcpp::export]]
Rcpp::List compare_backends_cpp(
    Rcpp::CharacterVector input,
    std::string mode,
    bool strict = true
) {
    Rcpp::CharacterVector fallback(input.size());
    Rcpp::CharacterVector libidn2(input.size());
    bool has_libidn2 = punycoder::libidn2_backend_available();
    bool verify_dns_length = mode == "encode_url" || mode == "decode_url";

    punycoder::PunycodeService fallback_service(
        strict,
        punycoder::select_label_backend(punycoder::BackendPreference::fallback),
        verify_dns_length
    );
    punycoder::PunycodeService libidn2_service(
        strict,
        punycoder::select_label_backend(punycoder::BackendPreference::libidn2),
        verify_dns_length
    );

    for (R_xlen_t i = 0; i < input.size(); ++i) {
        if (Rcpp::CharacterVector::is_na(input[i])) {
            fallback[i] = NA_STRING;
            libidn2[i] = NA_STRING;
            continue;
        }

        std::string value = Rcpp::as<std::string>(input[i]);
        fallback[i] = safe_backend_mode(fallback_service, mode, value);
        if (has_libidn2) {
            libidn2[i] = safe_backend_mode(libidn2_service, mode, value);
        } else {
            libidn2[i] = NA_STRING;
        }
    }

    return Rcpp::List::create(
        Rcpp::Named("available") = has_libidn2,
        Rcpp::Named("fallback") = fallback,
        Rcpp::Named("libidn2") = libidn2
    );
}

// Canonical-host normalization (dev/normalization-contract.md). NA inputs pass
// through as NA (missing); invalid inputs return NA (the contract's
// NA-on-invalid signal). The result is always lowercase ASCII, so no element
// encoding needs to be set. Names are preserved.
//
// [[Rcpp::export]]
Rcpp::CharacterVector host_normalize_cpp(Rcpp::CharacterVector x,
                                         bool check_hyphens = true,
                                         bool use_std3 = true,
                                         bool verify_dns_length = true) {
    R_xlen_t n = x.size();
    Rcpp::CharacterVector out(n);

    punycoder::NormalizeOptions opts;
    opts.check_hyphens = check_hyphens;
    opts.use_std3 = use_std3;
    opts.verify_dns_length = verify_dns_length;

    for (R_xlen_t i = 0; i < n; ++i) {
        if (Rcpp::CharacterVector::is_na(x[i])) {
            out[i] = NA_STRING;
            continue;
        }

        const punycoder::HostNormalizeResult result =
            punycoder::host_normalize_one(Rcpp::as<std::string>(x[i]), opts);
        out[i] = result.valid ? Rcpp::String(result.value) : NA_STRING;
    }

    out.attr("names") = x.attr("names");
    return out;
}

// Pinned Unicode version of the vendored UTS-46 + NFC data, the single source
// of truth read by normalization_profile_info() (contract section 7).
//
// [[Rcpp::export]]
std::string normalization_unicode_version_cpp() {
    return std::string(punycoder::u16::UNICODE_VERSION);
}
