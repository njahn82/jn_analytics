# jnanalytics 0.1.0.9000

First version. jnanalytics succeeds hoaddata 0.3: it covers all journals in
transformative agreements, hybrid and fully open access, and implements the
data model in `draft_implementation.md`. hoaddata 0.3 stays available
unchanged for code that relies on its tables.

* The build runs as a `targets` pipeline (`_targets.R`): only steps whose
  inputs changed rerun (raw files, SQL templates, Crossref/OpenAlex snapshots,
  calendar year). GitHub Actions runs it on demand (`build.yaml`) and checks the
  package on every push (`check.yaml`). New helpers `jn_bq_auth()`,
  `jn_snapshots()` and `jn_save_reference()`.
* Agreement coverage: new reference table `agreement_institutions` (JCT
  institutions with ROR IDs), article-level `article_agreements` in BigQuery
  (matches by corresponding or first author, direct, child, parent or related
  institution per OpenAlex, with the OpenAlex publication date within the
  agreement period) and the aggregate
  `agreement_journal_year` (direct, child and parent matches; related ones
  are kept for comparison only). Agreements missing
  from ESAC get an inferred period (`agreements.is_period_inferred`).
* pkgdown website with a README home page and a "Data model" article that
  documents every table, column and counting rule from the schema; deployed
  to GitHub Pages by `pkgdown.yaml`.
* `normalize_ror()` brings ROR IDs into one canonical form.
* A CC licence counts for the version of record whatever its start date in
  Crossref (`delay_in_days` is ignored), as in hoaddata 0.3.
* Every work in a fully OA journal-year counts as OA (`articles_oa`); in
  hybrid journal-years, OA means a CC licence in Crossref. The licence
  evidence alone is the new `articles_with_cc_license` in `journal_year`,
  `journal_year_country` and `agreement_journal_year`, reported by
  `jn_metadata()` as `share_cc_license`.
* All journal-year aggregates carry a year-aware `oa_model`: a journal counts
  as hybrid up to and including its OpenAlex `oa_flip_year` (a transition
  year) and as fully OA afterwards.
* `jn_oa()`, `jn_licenses()` and `jn_metadata()` give journal-level statistics
  per agreement: `by = "agreement_id"` and `agreement = <ESAC IDs>` cover all
  works in an agreement's journals, by default only in the years the agreement
  ran (`agreement_period`).
* The analysis functions cover all journals by default; split hybrid from
  fully OA journals with `by = "oa_model"` or filter with `oa_model`.

* The Journal Checker Tool is the only source of journals and agreements.
  German Open Access Monitor (OAM) agreements are no longer included.
* `journals` gains `oa_model` to tell hybrid from fully open access journals.
  Journals that hoaddata 0.3 dropped as fully OA are now kept and flagged.
* Dashboard pages (`portfolios`) move from hoaddash `config.csv` into the data,
  one row per page and agreement, so each page lists its ESAC IDs; its
  journals follow from `agreement_journals`.
* Journals get ISSN-Ls, titles, OpenAlex IDs and their OA model (`hybrid` or
  `full_oa`, plus `oa_flip_year`) from OpenAlex.
* Article and aggregate tables count works by OpenAlex `work_type`, so all
  works and research articles (`article`, `review`) come from the same tables.
* `jn_bq_config()` and `jn_sql()` define and render the BigQuery build;
  inputs are the OpenAlex (`openalex_walden`) and Crossref (`cr_instant`)
  snapshots, output goes to `subugoe-collaborative.jn_analytics`.
* `jn_oa()`, `jn_licenses()` and `jn_metadata()` compute OA shares,
  licence mix and metadata coverage for all journals or a portfolio, globally
  or by first-author country. They run unchanged on the Parquet export and on
  BigQuery via `jn_source()`; `jn_tbl()` gives direct access to any table,
  including article-level data in BigQuery.
* `jn_build()` builds all BigQuery tables in order: `articles`,
  `article_first_authors`, `journal_year`, `journal_year_country`,
  `journal_year_license` and `journal_year_country_license`. Country tables
  cover every first-author country (full counting) instead of a fixed
  Germany scope.
* `jn_publish()` exports the reference tables and journal-level aggregates
  as zstd-compressed Parquet with column descriptions in the file metadata,
  plus a `release` table (`jn_release()`) with version and snapshot dates.
* `jn_build_table()` builds a table in BigQuery from an `inst/sql` template
  and sets column descriptions from the schema; `jn_upload_reference()`
  uploads the reference tables. `articles` is the first table built this way.
* `jn_fetch_openalex_sources()` downloads OpenAlex journal metadata for the
  JCT journals.
* `jn_schema()`, `jn_tables()` and `jn_validate()` expose and enforce one
  schema for column names, types and descriptions
  (`inst/schema/columns.csv`). Package docs are generated from it.
* `jn_update_reference()` builds the reference tables `journals`,
  `journal_issns`, `agreements`, `agreement_journals` and `portfolios`.
