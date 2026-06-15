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

- The canonical-host normalization tables in `src/unicode_tables_16_0_0.cpp`
  are mechanically derived from the Unicode Character Database (UCD), version
  16.0.0, by `data-raw/generate_unicode_tables.R` (UnicodeData.txt,
  DerivedNormalizationProps.txt, and IdnaMappingTable.txt for UTS #46).
  - Homepage: https://www.unicode.org/Public/16.0.0/
  - License: Unicode License v3 (https://www.unicode.org/license.txt)

## Inspiration and compatibility notes

- This package is inspired by `urltools`.
- `punycoder` aims to provide a robust fix for punycode encode/decode issues
  that may arise in `urltools` workflows.
