# data-raw

Inputs for the bundled reference tables. Rebuild them from the package root with

```r
source("data-raw/reference.R")
```

| File | Content | Source |
| --- | --- | --- |
| `jct_jn_all.csv.gz` | Journal lists per agreement, with the last time each row was seen | JCT scraper <https://github.com/njahn82/jct_data> (`data/jct_jn_all.csv`), copied here by hand and gzipped (`gzip -9 jct_jn_all.csv`; 82 MB → 12 MB) |
| `jct_inst_all.csv` | Institutions (with ROR IDs) per agreement, with the last time each row was seen | JCT scraper (`data/`), copied here by hand |
| `esac_df.csv` | Agreement metadata: publisher, countries, lead organisation, dates | ESAC registry export, via the JCT scraper (`data/`), copied here by hand |
| `legacy/jct_hybrid_jns.csv.gz` | Agreement–ISSN links used by hoaddata 0.3 (JCT snapshots 2021–2026) | hoaddata 0.3.11 |
| `legacy/jct_institutions.csv` | Agreement institutions used by hoaddata 0.3 | hoaddata 0.3.11 |
| `legacy/journal_titles.csv` | Fallback journal titles (`jct_oalex_venues`) | hoaddata 0.3.11 |
| `openalex_sources.csv` | OpenAlex journals sharing an ISSN with the JCT lists: ISSNs, ISSN-L, title, `is_oa`, `is_in_doaj`, `oa_flip_year`. Primary source for ISSN-Ls and `oa_model` | `jn_fetch_openalex_sources()`, `openalex_walden.sources` |
| `manual/exclusions.csv` | Agreements to drop, with a reason | curated |
| `manual/oa_model.csv` | Journals with a known OA model (`hybrid` or `full_oa`), with a reason. Overrides any automatic classification | curated |
| `manual/oa_flips.csv` | Publishers that turned all their journals fully OA, with the first fully OA year (`full_oa_from`) and a source. Their hybrid and unclassified journals become `full_oa` with `oa_flip_year = full_oa_from - 1` | curated |
| `manual/publisher_names.csv` | Publisher name variants → normalised name | curated |
| `manual/agreement_publishers.csv` | Publisher for ESAC ID prefixes missing from `esac_df.csv` | curated |
| `manual/portfolios.csv` | Dashboard publisher pages (replaces the JCT part of hoaddash `config.csv`) | curated |
| `diagnostics/unmatched_jct.csv` | Output: JCT rows that could not be matched to an ISSN-L | generated |
| `diagnostics/institutions_without_ror.csv` | Output: JCT institutions without a valid ROR ID, not matchable | generated |
