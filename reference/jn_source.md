# Connect to the jnanalytics tables

The analysis functions read from a source: a folder of Parquet files as
written by
[`jn_publish()`](https://njahn82.github.io/jn_analytics/reference/jn_publish.md)
or downloaded from Hugging Face, or the BigQuery dataset. A table is
either one file (`journal_year.parquet`) or a folder of files
(`articles/articles_2025.parquet`, ...); a download of only some tables
or years works too.

## Usage

``` r
jn_source(x = "parquet", config = jn_bq_config())

jn_tbl(src, table)
```

## Arguments

- x:

  A directory with Parquet files, or `"bigquery"`.

- config:

  See
  [`jn_bq_config()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_config.md).
  Used for BigQuery only.

- src:

  A `jn_source`.

- table:

  Table name, see
  [`jn_tables()`](https://njahn82.github.io/jn_analytics/reference/jn_tables.md).

## Value

A `jn_source` object. `jn_tbl()` returns one of its tables as a lazy
table that dplyr verbs can be applied to.

## Examples

``` r
if (FALSE) { # \dontrun{
# hf download najkoja/jn_analytics --repo-type dataset --local-dir jn_data
src <- jn_source("jn_data")
jn_tbl(src, "journal_year")
jn_tbl(src, "articles") |>
  dplyr::filter(issn_l == "0360-0300", pub_year == 2025) |>
  dplyr::collect()

bq <- jn_source("bigquery")
jn_tbl(bq, "articles") |>
  dplyr::filter(issn_l == "0360-0300", pub_year == 2025) |>
  dplyr::collect()
} # }
```
