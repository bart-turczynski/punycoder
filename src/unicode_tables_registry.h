// Resolves the facade column of PUNYCODER_UNICODE_VERSIONS.
//
// Included ONLY by the two translation units that instantiate the pipeline
// (punycoder_nfc.cpp, punycoder_normalize.cpp). Everything else that needs the
// version enum or the version strings includes punycoder_unicode_version.h,
// which is a leaf.
//
// Adding a version is two adjacent hand edits: one #include here, one X(...)
// line there. #include cannot be macro-generated portably, so those two stay
// manual by design -- and both fail loudly if you do only one. Missing the
// X(...) means the version simply does not exist; missing the #include is a
// compile error where the facade column expands.
#ifndef PUNYCODER_UNICODE_TABLES_REGISTRY_H
#define PUNYCODER_UNICODE_TABLES_REGISTRY_H

#include "punycoder_unicode_version.h"
#include "unicode_tables_16_0_0.h"

#endif  // PUNYCODER_UNICODE_TABLES_REGISTRY_H
