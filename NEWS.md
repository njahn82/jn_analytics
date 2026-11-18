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
* All tables, including the article tables, are published as Parquet files
  in the Hugging Face dataset `najkoja/jn_analytics`, one tagged commit per
  release (named after the build date), with a generated dataset card. New
  `jn_upload_hf()`; the pipeline exports and uploads after each build. The
  Parquet files are no longer committed to `parquet/` of the repository.
  The website's "Download the data" page links to Hugging Face.
* `jn_publish()` exports all tables (see `jn_publish_tables()`); the article
  tables are written as one file per publication year
  (`articles/articles_2025.parquet`, ...).
* The article tables are partitioned by `pub_year` in BigQuery, so queries
  and exports for single years scan less. `article_first_authors` and
  `article_agreements` have a new `pub_year` column.
* `jn_source()` reads tables stored as a folder of files, so the article
  tables can be analysed from a download as well as from BigQuery.
* Two new tables for drill-downs by institution, for example in the
  dashboard: `agreement_articles` lists every eligible work per agreement,
  participating institution and author role with its journal, type and OA
  status (no joins needed), and `agreement_institution_year` sums it per
  institution, year, OA model and work type. `agreement_articles` is
  clustered by agreement and institution in BigQuery and sorted that way in
  its yearly Parquet files, so a query for one agreement reads little data.
* Agreement coverage counts a `parent` match only if the agreement lists at
  least two institutions whose only parent it is (an umbrella organisation
  such as CSIC or the Chinese Academy of Sciences). Otherwise the match is
  stored as `parent_single` and not counted: OpenAlex lists the shareholders
  of European XFEL (CNRS, INFN, CEA and others) as its parents, and Spanish
  universities as parents of joint institutes with CSIC, which made their
  authors eligible under agreements that do not cover them. In 2025 this
  removes about 24,000 of 25,500 work-agreement pairs counted only through a
  parent.
* Curated corrections of the JCT institution lists in
  `data-raw/manual/institution_corrections.csv` add or remove participating
  institutions per agreement, with their source. The first fixes
  `ieee2025cas` (IEEE and DRAA) against IEEE's partner list: six universities
  added, among them South China University of Technology, and fourteen
  removed. A correction that no longer applies stops the build.
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
* Publisher-wide flips to open access are curated in
  `data-raw/manual/oa_flips.csv`. ACM journals count as fully OA from 2026.
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
