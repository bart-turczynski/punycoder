#include <Rcpp.h>

#include <stdexcept>
#include <string>

#include "punycoder_core.h"
#include "punycoder_normalize.h"
#include "punycoder_unicode_version.h"

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

            const std::string value = fn(Rcpp::as<std::string>(input[i]));
            output[i] = Rcpp::String(value, CE_UTF8);
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
                punycoder::throw_error(punycoder::ErrorCode::looks_like_url);
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
                punycoder::throw_error(punycoder::ErrorCode::looks_like_url);
            }
            return service.decode_domain(domain);
        }
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
        } catch (const std::exception& e) {  // # nocov start
            // Defensive: validate_and_parse_domain only throws PunycoderError;
            // this arm catches non-domain exceptions (e.g. std::bad_alloc).
            valid[i] = false;
            errors[i] = Rcpp::CharacterVector::create(e.what());
            error_codes[i] = Rcpp::CharacterVector::create("unknown_error");
        }  // # nocov end
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
    bool verify_dns_length = false;

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
        fallback[i] = Rcpp::String(
            safe_backend_mode(fallback_service, mode, value),
            CE_UTF8
        );
        if (has_libidn2) {
            libidn2[i] = Rcpp::String(
                safe_backend_mode(libidn2_service, mode, value),
                CE_UTF8
            );
        } else {
            libidn2[i] = NA_STRING;  // # nocov (only on builds without libidn2, e.g. Windows)
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
// `unicode_version` selects the table set and is always an explicit string: R
// resolves its own NULL-means-the-pin default before calling, so no version
// argument is ever absent by the time it reaches here. An unshipped version
// stops rather than returning NA -- that is a caller error, not invalid host
// data, and silently falling back to the default would make a reproducibility
// key describe a normalization that never happened (PUNY-nblrvplp). R checks
// first and produces the actionable message; this check is the backstop for
// the internal callers that bypass it.
//
// [[Rcpp::export]]
Rcpp::CharacterVector host_normalize_cpp(Rcpp::CharacterVector x,
                                         std::string unicode_version,
                                         bool check_hyphens = true,
                                         bool use_std3 = true,
                                         bool verify_dns_length = true) {
    R_xlen_t n = x.size();
    Rcpp::CharacterVector out(n);

    punycoder::NormalizeOptions opts;
    opts.check_hyphens = check_hyphens;
    opts.use_std3 = use_std3;
    opts.verify_dns_length = verify_dns_length;
    if (!punycoder::unicode_version_from_string(unicode_version.c_str(),
                                                opts.unicode_version)) {
        Rcpp::stop("Unsupported Unicode version: " + unicode_version);
    }

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

// Unicode version of the table set host_normalize() uses by default -- the
// single source of truth read by normalization_profile_info() (contract
// section 7). Reported from the version registry rather than from a table
// header, so this file does not recompile when a table set is added.
//
// [[Rcpp::export]]
std::string normalization_unicode_version_cpp() {
    return std::string(
        punycoder::unicode_version_string(punycoder::kDefaultUnicodeVersion));
}

// Every shipped table set: the string the registry gives it, the string its own
// table unit reports (see table_reported_version(), which is how a facade
// paired with the wrong version is caught), and which one is the pinned
// default. Backs the exported unicode_versions() and the actionable
// "shipped versions are ..." half of an unsupported-version error.
//
// [[Rcpp::export]]
Rcpp::List unicode_versions_cpp() {
    const std::size_t n = punycoder::unicode_version_count();
    Rcpp::CharacterVector registry(n);
    Rcpp::CharacterVector reported(n);

    for (std::size_t i = 0; i < n; ++i) {
        const punycoder::UnicodeVersion v = punycoder::unicode_version_at(i);
        registry[i] = punycoder::unicode_version_string(v);
        reported[i] = punycoder::table_reported_version(v);
    }

    return Rcpp::List::create(
        Rcpp::Named("version") = registry,
        Rcpp::Named("reported") = reported,
        Rcpp::Named("default") = std::string(punycoder::unicode_version_string(
            punycoder::kDefaultUnicodeVersion))
    );
}

