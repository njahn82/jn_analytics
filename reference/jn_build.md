# Build all jnanalytics tables in BigQuery

Uploads the reference tables, then builds the article tables and the
aggregates in dependency order: `articles`, `article_first_authors`,
`journal_year`, `journal_year_country`, `journal_year_license`,
`journal_year_country_license`, `article_agreements` and
`agreement_journal_year`.

## Usage

``` r
jn_build(
  config = jn_bq_config(),
  year_min = 2016L,
  year_max = as.integer(format(Sys.Date(), "%Y")),
  tables = jn_build_order(),
  upload = TRUE,
  max_gb = 200
)
```

## Arguments

- config:

  See
  [`jn_bq_config()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_config.md).

- year_min, year_max:

  Publication years covered.

- tables:

  Tables to build, in this order. Defaults to all.

- upload:

  If `TRUE`, upload the reference tables first.

- max_gb:

  Stop without running if the query would scan more than this.

## Value

The built BigQuery tables, invisibly.
