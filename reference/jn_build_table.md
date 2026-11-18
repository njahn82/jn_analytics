# Build a table in BigQuery from a SQL template

Renders `inst/sql/<name>.sql` with
[`jn_sql()`](https://njahn82.github.io/jn_analytics/reference/jn_sql.md),
reports the bytes the query will scan, writes the result to
`<project>.<dataset>.<name>` (replacing it) and sets the column
descriptions from
[`jn_schema()`](https://njahn82.github.io/jn_analytics/reference/jn_schema.md).
The article tables (`articles`, `article_first_authors`,
`article_agreements`) are partitioned by `pub_year`, so queries for
single years scan less.

## Usage

``` r
jn_build_table(
  name,
  config = jn_bq_config(),
  year_min = 2016L,
  year_max = as.integer(format(Sys.Date(), "%Y")),
  max_gb = 200,
  dry_run = FALSE
)
```

## Arguments

- name:

  Table and template name, e.g. `"articles"`.

- config:

  See
  [`jn_bq_config()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_config.md).

- year_min, year_max:

  Publication years covered.

- max_gb:

  Stop without running if the query would scan more than this.

- dry_run:

  If `TRUE`, only report the bytes that would be scanned.

## Value

The BigQuery table, invisibly (or the bytes, for a dry run).
