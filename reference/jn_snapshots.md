# Snapshot dates of the input datasets

Reads the "Snapshot date" from the descriptions of the Crossref and
OpenAlex tables. The pipeline rebuilds the BigQuery tables when they
change.

## Usage

``` r
jn_snapshots(config = jn_bq_config())
```

## Arguments

- config:

  See
  [`jn_bq_config()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_config.md).

## Value

A list with `crossref` and `openalex`.
