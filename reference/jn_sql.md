# Render a SQL template from `inst/sql`

Replaces `{{name}}` placeholders. `{{dataset}}`, `{{openalex}}` and
`{{crossref}}` come from `config`; `{{year_min}}` and `{{year_max}}`
from the arguments.

## Usage

``` r
jn_sql(
  name,
  config = jn_bq_config(),
  year_min = 2016L,
  year_max = as.integer(format(Sys.Date(), "%Y"))
)
```

## Arguments

- name:

  Basename of the SQL file, e.g. `"articles"`.

- config:

  See
  [`jn_bq_config()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_config.md).

- year_min, year_max:

  Publication years covered.

## Value

The SQL as a single string.

## Examples

``` r
cat(jn_sql("openalex_sources"))
#> -- OpenAlex journals with all their ISSNs, one row per source and ISSN.
#> -- Used to map JCT ISSNs to ISSN-Ls and to classify journals as hybrid or
#> -- fully open access. The result is filtered to JCT journals in R.
#> SELECT
#>   s.id AS openalex_source_id,
#>   s.issn_l,
#>   issn,
#>   s.display_name AS title,
#>   s.host_organization_name AS host_organization,
#>   s.type AS source_type,
#>   s.is_oa,
#>   s.is_in_doaj,
#>   s.oa_flip_year,
#>   s.works_count
#> FROM `subugoe-collaborative.openalex_walden.sources` AS s,
#>   UNNEST(s.issn) AS issn
#> WHERE s.issn_l IS NOT NULL
```
