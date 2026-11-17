# Connect to the jnanalytics tables

The analysis functions read from a source: the Parquet files written by
[`jn_publish()`](https://njahn82.github.io/jn_analytics/reference/jn_publish.md)
(journal-level tables only), or the BigQuery dataset (all tables,
including the article-level `articles` and `article_first_authors`).

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
src <- jn_source("parquet")
jn_tbl(src, "journal_year")

# Article-level data is only in BigQuery
bq <- jn_source("bigquery")
jn_tbl(bq, "articles") |>
  dplyr::filter(issn_l == "0360-0300", pub_year == 2025) |>
  dplyr::collect()
} # }
```
