# Describe a release

One-row `release` table: package version, build date, the Crossref,
OpenAlex and Journal Checker Tool snapshots used, and the publication
years covered.

## Usage

``` r
jn_release(journal_year, raw_dir = "data-raw", config = jn_bq_config())
```

## Arguments

- journal_year:

  The `journal_year` table, for the years covered.

- raw_dir:

  Directory with `jct_jn_all.csv.gz`.

- config:

  See
  [`jn_bq_config()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_config.md).

## Value

A tibble matching `jn_schema("release")`.
