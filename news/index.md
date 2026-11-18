# Changelog

## jnanalytics 0.1.0.9000

First version. jnanalytics succeeds hoaddata 0.3: it covers all journals
in transformative agreements, hybrid and fully open access, and
implements the data model in `draft_implementation.md`. hoaddata 0.3
stays available unchanged for code that relies on its tables.

- The build runs as a `targets` pipeline (`_targets.R`): only steps
  whose inputs changed rerun (raw files, SQL templates,
  Crossref/OpenAlex snapshots, calendar year). GitHub Actions runs it on
  demand (`build.yaml`) and checks the package on every push
  (`check.yaml`). New helpers
  [`jn_bq_auth()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_auth.md),
  [`jn_snapshots()`](https://njahn82.github.io/jn_analytics/reference/jn_snapshots.md)
  and
  [`jn_save_reference()`](https://njahn82.github.io/jn_analytics/reference/jn_save_reference.md).

- Agreement coverage: new reference table `agreement_institutions` (JCT
  institutions with ROR IDs), article-level `article_agreements` in
  BigQuery (matches by corresponding or first author, direct, child,
  parent or related institution per OpenAlex, with the OpenAlex
  publication date within the agreement period) and the aggregate
  `agreement_journal_year` (direct, child and parent matches; related
  ones are kept for comparison only). Agreements missing from ESAC get
  an inferred period (`agreements.is_period_inferred`).

- pkgdown website with a README home page and a “Data model” article
  that documents every table, column and counting rule from the schema;
  deployed to GitHub Pages by `pkgdown.yaml`.

- All tables, including the article tables, are published as Parquet
  files in the Hugging Face dataset `najkoja/jn_analytics`, one tagged
  commit per release (named after the build date), with a generated
  dataset card. New
  [`jn_upload_hf()`](https://njahn82.github.io/jn_analytics/reference/jn_upload_hf.md);
  the pipeline exports and uploads after each build. The Parquet files
  are no longer committed to `parquet/` of the repository. The website’s
  “Download the data” page links to Hugging Face.

- [`jn_publish()`](https://njahn82.github.io/jn_analytics/reference/jn_publish.md)
  exports all tables (see
  [`jn_publish_tables()`](https://njahn82.github.io/jn_analytics/reference/jn_publish_tables.md));
  the article tables are written as one file per publication year
  (`articles/articles_2025.parquet`, …).

- The article tables are partitioned by `pub_year` in BigQuery, so
  queries and exports for single years scan less.
  `article_first_authors` and `article_agreements` have a new `pub_year`
  column.

- [`jn_source()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md)
  reads tables stored as a folder of files, so the article tables can be
  analysed from a download as well as from BigQuery.

- Curated corrections of the JCT institution lists in
  `data-raw/manual/institution_corrections.csv` add or remove
  participating institutions per agreement, with their source. The first
  fixes `ieee2025cas` (IEEE and DRAA) against IEEE’s partner list: six
  universities added, among them South China University of Technology,
  and fourteen removed. A correction that no longer applies stops the
  build.

- [`normalize_ror()`](https://njahn82.github.io/jn_analytics/reference/normalize_ror.md)
  brings ROR IDs into one canonical form.

- A CC licence counts for the version of record whatever its start date
  in Crossref (`delay_in_days` is ignored), as in hoaddata 0.3.

- Every work in a fully OA journal-year counts as OA (`articles_oa`); in
  hybrid journal-years, OA means a CC licence in Crossref. The licence
  evidence alone is the new `articles_with_cc_license` in
  `journal_year`, `journal_year_country` and `agreement_journal_year`,
  reported by
  [`jn_metadata()`](https://njahn82.github.io/jn_analytics/reference/jn_oa.md)
  as `share_cc_license`.

- All journal-year aggregates carry a year-aware `oa_model`: a journal
  counts as hybrid up to and including its OpenAlex `oa_flip_year` (a
  transition year) and as fully OA afterwards.

- Publisher-wide flips to open access are curated in
  `data-raw/manual/oa_flips.csv`. ACM journals count as fully OA from
  2026.

- [`jn_oa()`](https://njahn82.github.io/jn_analytics/reference/jn_oa.md),
  [`jn_licenses()`](https://njahn82.github.io/jn_analytics/reference/jn_oa.md)
  and
  [`jn_metadata()`](https://njahn82.github.io/jn_analytics/reference/jn_oa.md)
  give journal-level statistics per agreement: `by = "agreement_id"` and
  `agreement = <ESAC IDs>` cover all works in an agreement’s journals,
  by default only in the years the agreement ran (`agreement_period`).

- The analysis functions cover all journals by default; split hybrid
  from fully OA journals with `by = "oa_model"` or filter with
  `oa_model`.

- The Journal Checker Tool is the only source of journals and
  agreements. German Open Access Monitor (OAM) agreements are no longer
  included.

- `journals` gains `oa_model` to tell hybrid from fully open access
  journals. Journals that hoaddata 0.3 dropped as fully OA are now kept
  and flagged.

- Dashboard pages (`portfolios`) move from hoaddash `config.csv` into
  the data, one row per page and agreement, so each page lists its ESAC
  IDs; its journals follow from `agreement_journals`.

- Journals get ISSN-Ls, titles, OpenAlex IDs and their OA model
  (`hybrid` or `full_oa`, plus `oa_flip_year`) from OpenAlex.

- Article and aggregate tables count works by OpenAlex `work_type`, so
  all works and research articles (`article`, `review`) come from the
  same tables.

- [`jn_bq_config()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_config.md)
  and
  [`jn_sql()`](https://njahn82.github.io/jn_analytics/reference/jn_sql.md)
  define and render the BigQuery build; inputs are the OpenAlex
  (`openalex_walden`) and Crossref (`cr_instant`) snapshots, output goes
  to `subugoe-collaborative.jn_analytics`.

- [`jn_oa()`](https://njahn82.github.io/jn_analytics/reference/jn_oa.md),
  [`jn_licenses()`](https://njahn82.github.io/jn_analytics/reference/jn_oa.md)
  and
  [`jn_metadata()`](https://njahn82.github.io/jn_analytics/reference/jn_oa.md)
  compute OA shares, licence mix and metadata coverage for all journals
  or a portfolio, globally or by first-author country. They run
  unchanged on the Parquet export and on BigQuery via
  [`jn_source()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md);
  [`jn_tbl()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md)
  gives direct access to any table, including article-level data in
  BigQuery.

- [`jn_build()`](https://njahn82.github.io/jn_analytics/reference/jn_build.md)
  builds all BigQuery tables in order: `articles`,
  `article_first_authors`, `journal_year`, `journal_year_country`,
  `journal_year_license` and `journal_year_country_license`. Country
  tables cover every first-author country (full counting) instead of a
  fixed Germany scope.

- [`jn_publish()`](https://njahn82.github.io/jn_analytics/reference/jn_publish.md)
  exports the reference tables and journal-level aggregates as
  zstd-compressed Parquet with column descriptions in the file metadata,
  plus a `release` table
  ([`jn_release()`](https://njahn82.github.io/jn_analytics/reference/jn_release.md))
  with version and snapshot dates.

- [`jn_build_table()`](https://njahn82.github.io/jn_analytics/reference/jn_build_table.md)
  builds a table in BigQuery from an `inst/sql` template and sets column
  descriptions from the schema;
  [`jn_upload_reference()`](https://njahn82.github.io/jn_analytics/reference/jn_upload_reference.md)
  uploads the reference tables. `articles` is the first table built this
  way.

- [`jn_fetch_openalex_sources()`](https://njahn82.github.io/jn_analytics/reference/jn_fetch_openalex_sources.md)
  downloads OpenAlex journal metadata for the JCT journals.

- [`jn_schema()`](https://njahn82.github.io/jn_analytics/reference/jn_schema.md),
  [`jn_tables()`](https://njahn82.github.io/jn_analytics/reference/jn_tables.md)
  and
  [`jn_validate()`](https://njahn82.github.io/jn_analytics/reference/jn_validate.md)
  expose and enforce one schema for column names, types and descriptions
  (`inst/schema/columns.csv`). Package docs are generated from it.

- [`jn_update_reference()`](https://njahn82.github.io/jn_analytics/reference/jn_update_reference.md)
  builds the reference tables `journals`, `journal_issns`, `agreements`,
  `agreement_journals` and `portfolios`.
