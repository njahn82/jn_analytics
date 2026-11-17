# Upload the reference tables to BigQuery

Writes `journals`, `journal_issns`, `agreements`, `agreement_journals`,
`agreement_institutions` and `portfolios` to the jnanalytics dataset,
replacing existing tables. Column types and descriptions come from
[`jn_schema()`](https://njahn82.github.io/jn_analytics/reference/jn_schema.md).
Load jobs are free.

## Usage

``` r
jn_upload_reference(ref = NULL, config = jn_bq_config())
```

## Arguments

- ref:

  Named list of reference tables. Defaults to the bundled data. With all
  six tables, foreign keys between them are checked too.

- config:

  See
  [`jn_bq_config()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_config.md).

## Value

The BigQuery tables, invisibly.
