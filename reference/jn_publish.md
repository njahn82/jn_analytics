# Export the published tables as Parquet

Downloads the reference tables and the journal-level aggregates from
BigQuery, validates them against
[`jn_schema()`](https://njahn82.github.io/jn_analytics/reference/jn_schema.md)
and writes one zstd-compressed Parquet file per table to `path`, plus a
`release` table that is also uploaded to BigQuery. Article-level tables
stay in BigQuery.

## Usage

``` r
jn_publish(
  path,
  tables = jn_publish_tables(),
  raw_dir = "data-raw",
  config = jn_bq_config()
)
```

## Arguments

- path:

  Directory to write to, e.g. the dashboard's `docs/data/`.

- tables:

  Tables to export.

- raw_dir, config:

  See
  [`jn_release()`](https://njahn82.github.io/jn_analytics/reference/jn_release.md).

## Value

The written file paths, invisibly.

## Details

Each file carries its table name, the package version and the column
descriptions as Parquet key-value metadata (`jn_table`, `jn_version`,
`jn_columns` as JSON), readable for example with DuckDB's
`parquet_kv_metadata()`.
