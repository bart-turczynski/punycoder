// The Unicode table versions this build ships.
//
// PUNYCODER_UNICODE_VERSIONS is the single source of truth: the enum below, the
// version strings, the explicit template instantiations in punycoder_nfc.cpp
// and punycoder_normalize.cpp, and the dispatch switch in host_normalize_one()
// are all expansions of this one list.
//
// The third column names a facade TYPE, but this header includes no table
// header and does not need to: a macro argument is only a token sequence until
// something expands it. A translation unit that wants the enum and the strings
// expands the list with an X that drops the third column and never looks the
// name up. Only the two units that instantiate the pipeline expand the facade
// column, and they include unicode_tables_registry.h to resolve it. That is
// what keeps the generated table headers leaves, and what keeps a version bump
// from recompiling exports.cpp.
#ifndef PUNYCODER_UNICODE_VERSION_H
#define PUNYCODER_UNICODE_VERSION_H

#include <cstddef>

namespace punycoder {

//        X(enumerator, version string, facade type)
#define PUNYCODER_UNICODE_VERSIONS(X)                \
    X(v16_0_0, "16.0.0", ::punycoder::u16::Tables)   \
    X(v17_0_0, "17.0.0", ::punycoder::u17::Tables)

enum class UnicodeVersion {
#define PUNYCODER_UV_ENUMERATOR(name, str, facade) name,
    PUNYCODER_UNICODE_VERSIONS(PUNYCODER_UV_ENUMERATOR)
#undef PUNYCODER_UV_ENUMERATOR
};

// The version used when a caller does not choose one. Named explicitly rather
// than derived from the ends of the list: the newest shipped table set is not
// automatically the default, and promoting one is a deliberate edit here.
constexpr UnicodeVersion kDefaultUnicodeVersion = UnicodeVersion::v16_0_0;

// Version string ("16.0.0") for v, or "" if v is not a shipped version.
const char* unicode_version_string(UnicodeVersion v) noexcept;

// Parse a version string into out; false (leaving out untouched) if unshipped.
bool unicode_version_from_string(const char* s, UnicodeVersion& out) noexcept;

// Enumerate the shipped versions, so callers need not restate the list.
std::size_t unicode_version_count() noexcept;
UnicodeVersion unicode_version_at(std::size_t i) noexcept;

}  // namespace punycoder

#endif  // PUNYCODER_UNICODE_VERSION_H
