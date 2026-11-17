# Rebuild the bundled reference tables from the raw files in data-raw/.
# Run from the package root: source("data-raw/reference.R")
pkgload::load_all()

ref <- jn_update_reference("data-raw")

jn_save_reference(ref, "data")

# Journal-list rows without ISSN-L, for review
readr::write_csv(ref$diagnostics$unmatched_jct, "data-raw/diagnostics/unmatched_jct.csv")
readr::write_csv(
  ref$diagnostics$institutions_without_ror,
  "data-raw/diagnostics/institutions_without_ror.csv"
)
