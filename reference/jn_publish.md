# Export the published tables as Parquet

Downloads tables from BigQuery, validates them against
[`jn_schema()`](https://njahn82.github.io/jn_analytics/reference/jn_schema.md)
and writes zstd-compressed Parquet files to `path`, in the layout of the
Hugging Face dataset (see
[`jn_upload_hf()`](https://njahn82.github.io/jn_analytics/reference/jn_upload_hf.md)):

## Usage

``` r
jn_publish(
  path,
  tables = jn_publish_tables(),
  raw_dir = "data-raw",
  config = jn_bq_config(),
  max_gb = 30
)
```

## Arguments

- path:

  Directory to write to.

- tables:

  Tables to export, see
  [`jn_publish_tables()`](https://njahn82.github.io/jn_analytics/reference/jn_publish_tables.md).

- raw_dir, config:

  See
  [`jn_release()`](https://njahn82.github.io/jn_analytics/reference/jn_release.md).

- max_gb:

  Stop before exporting an article table whose queries would scan more
  than this.

## Value

The written file paths, invisibly.

## Details

- one file per table for the reference tables and the journal-level
  aggregates, e.g. `journal_year.parquet`, plus a `release` table
  (written with `journal_year` and also uploaded to BigQuery);

- one folder per article table with one file per publication year, e.g.
  `articles/articles_2025.parquet`. These are read year by year from the
  tables partitioned by `pub_year` (see
  [`jn_build_table()`](https://njahn82.github.io/jn_analytics/reference/jn_build_table.md)),
  so each query scans only that year. Old files in the folder are
  removed first.

Each file carries its table name, the package version and the column
descriptions as Parquet key-value metadata (`jn_table`, `jn_version`,
`jn_columns` as JSON), readable for example with DuckDB's
`parquet_kv_metadata()`.
