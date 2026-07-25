# Third-Party Notices and Acknowledgments

Project: punycoder  
Copyright (c) 2026 Bart Turczynski  
Contact: bartek+punycoder@turczynski.pl

## Third-party libraries

- Rcpp (`Imports`, `LinkingTo`): used for the R/C++ interface layer.
  - Homepage: https://cran.r-project.org/package=Rcpp
  - License: GPL (>= 2)
- GNU libidn2 (optional system dependency): used as an optional native
  punycode backend when available at build time.
  - Homepage: https://www.gnu.org/software/libidn/#libidn2
  - License: dual-licensed under LGPLv3+ or GPLv2+

## Unicode Character Database

- The canonical-host normalization tables in `src/unicode_tables_<version>.cpp`
  are mechanically derived from the Unicode Character Database (UCD) by
  `data-raw/generate_unicode_tables.R` (UnicodeData.txt,
  DerivedNormalizationProps.txt, and IdnaMappingTable.txt for UTS #46). One
  self-contained table unit is generated and compiled in per shipped version.
  - `src/unicode_tables_16_0_0.cpp`, from UCD version 16.0.0
    - Homepage: https://www.unicode.org/Public/16.0.0/
  - `src/unicode_tables_17_0_0.cpp`, from UCD version 17.0.0
    - Homepage: https://www.unicode.org/Public/17.0.0/
  - License: Unicode License v3 (https://www.unicode.org/license.txt)
- `inst/testdata/IdnaTestV2-<version>.txt` are the official UTS #46 conformance
  corpora, one per shipped Unicode version, vendored verbatim from the Unicode
  Character Database by `data-raw/fetch_idna_fixtures.R`. They are used by
  `tests/testthat/test-idna-conformance.R` to verify `host_normalize()` against
  the standard at each version it can normalize with.
  - `inst/testdata/IdnaTestV2-16.0.0.txt`, version 16.0.0 (dated 2024-07-03)
    - Homepage: https://www.unicode.org/Public/16.0.0/idna/IdnaTestV2.txt
  - `inst/testdata/IdnaTestV2-17.0.0.txt`, version 17.0.0 (dated 2025-05-01)
    - Homepage: https://www.unicode.org/Public/17.0.0/idna/IdnaTestV2.txt
  - License: Unicode License v3 (https://www.unicode.org/license.txt)

## Inspiration and compatibility notes

- This package is inspired by `urltools`.
- `punycoder` aims to provide a robust fix for punycode encode/decode issues
  that may arise in `urltools` workflows.
