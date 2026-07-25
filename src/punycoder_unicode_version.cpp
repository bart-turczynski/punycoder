#include "punycoder_unicode_version.h"

#include <cstring>

namespace punycoder {
namespace {

struct Entry {
    UnicodeVersion v;
    const char* str;
};

// Expanded from the same list as the enum, so the two cannot drift.
const Entry kEntries[] = {
#define PUNYCODER_UV_ENTRY(name, str, facade) {UnicodeVersion::name, str},
    PUNYCODER_UNICODE_VERSIONS(PUNYCODER_UV_ENTRY)
#undef PUNYCODER_UV_ENTRY
};

}  // namespace

std::size_t unicode_version_count() noexcept {
    return sizeof(kEntries) / sizeof(kEntries[0]);
}

UnicodeVersion unicode_version_at(std::size_t i) noexcept {
    return kEntries[i].v;
}

const char* unicode_version_string(UnicodeVersion v) noexcept {
    for (std::size_t i = 0; i < unicode_version_count(); ++i) {
        if (kEntries[i].v == v) return kEntries[i].str;
    }
    return "";  // # nocov (enum is closed; every enumerator is in kEntries)
}

bool unicode_version_from_string(const char* s, UnicodeVersion& out) noexcept {
    for (std::size_t i = 0; i < unicode_version_count(); ++i) {
        if (std::strcmp(s, kEntries[i].str) == 0) {
            out = kEntries[i].v;
            return true;
        }
    }
    return false;
}

}  // namespace punycoder
