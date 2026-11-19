# Package index

## Reference tables

Journals, agreements and dashboard portfolios, shipped with the package.
Every other table joins to them by `issn_l` or `agreement_id`.

- [`journals`](https://njahn82.github.io/jn_analytics/reference/journals.md)
  : Journals
- [`journal_issns`](https://njahn82.github.io/jn_analytics/reference/journal_issns.md)
  : Journal ISSNs
- [`agreements`](https://njahn82.github.io/jn_analytics/reference/agreements.md)
  : Transformative agreements
- [`agreement_journals`](https://njahn82.github.io/jn_analytics/reference/agreement_journals.md)
  : Journals covered by transformative agreements
- [`agreement_institutions`](https://njahn82.github.io/jn_analytics/reference/agreement_institutions.md)
  : Institutions participating in transformative agreements
- [`portfolios`](https://njahn82.github.io/jn_analytics/reference/portfolios.md)
  : Dashboard portfolios

## Analysis

The same functions run on the Parquet files and on BigQuery.

- [`jn_download()`](https://njahn82.github.io/jn_analytics/reference/jn_download.md)
  : Download the jnanalytics data
- [`jn_oa()`](https://njahn82.github.io/jn_analytics/reference/jn_oa.md)
  [`jn_licenses()`](https://njahn82.github.io/jn_analytics/reference/jn_oa.md)
  [`jn_metadata()`](https://njahn82.github.io/jn_analytics/reference/jn_oa.md)
  : Open access in the journal market
- [`jn_source()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md)
  [`jn_tbl()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md)
  : Connect to the jnanalytics tables

## Schema

One schema for column names, types and descriptions, used for
validation, the BigQuery column descriptions and the Parquet metadata.

- [`jn_schema()`](https://njahn82.github.io/jn_analytics/reference/jn_schema.md)
  : Column schema of the jnanalytics data model
- [`jn_tables()`](https://njahn82.github.io/jn_analytics/reference/jn_tables.md)
  : Tables in the jnanalytics data model
- [`jn_validate()`](https://njahn82.github.io/jn_analytics/reference/jn_validate.md)
  : Validate a table against the jnanalytics schema

## Building the data

Reference tables from the raw JCT and ESAC files, BigQuery tables from
the SQL templates in `inst/sql`, the Parquet export and its upload to
Hugging Face. Usually run through the targets pipeline in `_targets.R`.

- [`jn_update_reference()`](https://njahn82.github.io/jn_analytics/reference/jn_update_reference.md)
  : Build the reference tables

- [`jn_save_reference()`](https://njahn82.github.io/jn_analytics/reference/jn_save_reference.md)
  : Save the reference tables as package data

- [`jn_fetch_openalex_sources()`](https://njahn82.github.io/jn_analytics/reference/jn_fetch_openalex_sources.md)
  : Fetch OpenAlex journal metadata for the JCT journals

- [`jn_upload_reference()`](https://njahn82.github.io/jn_analytics/reference/jn_upload_reference.md)
  : Upload the reference tables to BigQuery

- [`jn_build()`](https://njahn82.github.io/jn_analytics/reference/jn_build.md)
  : Build all jnanalytics tables in BigQuery

- [`jn_build_table()`](https://njahn82.github.io/jn_analytics/reference/jn_build_table.md)
  : Build a table in BigQuery from a SQL template

- [`jn_publish()`](https://njahn82.github.io/jn_analytics/reference/jn_publish.md)
  : Export the published tables as Parquet

- [`jn_publish_tables()`](https://njahn82.github.io/jn_analytics/reference/jn_publish_tables.md)
  :

  Tables exported by
  [`jn_publish()`](https://njahn82.github.io/jn_analytics/reference/jn_publish.md)

- [`jn_release()`](https://njahn82.github.io/jn_analytics/reference/jn_release.md)
  : Describe a release

- [`jn_upload_hf()`](https://njahn82.github.io/jn_analytics/reference/jn_upload_hf.md)
  : Upload a release to Hugging Face

## BigQuery

- [`jn_bq_config()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_config.md)
  : BigQuery locations used by the build

- [`jn_bq_auth()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_auth.md)
  : Authenticate with BigQuery

- [`jn_bq_fields()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_fields.md)
  : BigQuery fields for a jnanalytics table

- [`jn_sql()`](https://njahn82.github.io/jn_analytics/reference/jn_sql.md)
  :

  Render a SQL template from `inst/sql`

- [`jn_snapshots()`](https://njahn82.github.io/jn_analytics/reference/jn_snapshots.md)
  : Snapshot dates of the input datasets

## Normalisation

- [`normalize_issn()`](https://njahn82.github.io/jn_analytics/reference/normalize_issn.md)
  : Normalise ISSNs
- [`normalize_publisher()`](https://njahn82.github.io/jn_analytics/reference/normalize_publisher.md)
  : Normalise publisher names
- [`normalize_ror()`](https://njahn82.github.io/jn_analytics/reference/normalize_ror.md)
  : Normalise ROR IDs

## Package

- [`jnanalytics`](https://njahn82.github.io/jn_analytics/reference/jnanalytics-package.md)
  [`jnanalytics-package`](https://njahn82.github.io/jn_analytics/reference/jnanalytics-package.md)
  : jnanalytics: Open Data About the Journal Market in Transformative
  Agreements
