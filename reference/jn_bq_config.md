# BigQuery locations used by the build

All tables built by jnanalytics go into one dataset. Inputs come from
the Crossref and OpenAlex snapshots in `subugoe-collaborative` only.

## Usage

``` r
jn_bq_config(
  project = "subugoe-collaborative",
  dataset = "jn_analytics",
  openalex = "subugoe-collaborative.openalex_walden",
  crossref = "subugoe-collaborative.cr_instant",
  billing = project
)
```

## Arguments

- project, dataset:

  Where jnanalytics writes its tables.

- openalex, crossref:

  Fully qualified datasets with the OpenAlex (Walden) and Crossref
  snapshots.

- billing:

  Project billed for queries.

## Value

A named list, used as default by the build functions.

## Examples

``` r
jn_bq_config()
#> $project
#> [1] "subugoe-collaborative"
#> 
#> $dataset
#> [1] "jn_analytics"
#> 
#> $openalex
#> [1] "subugoe-collaborative.openalex_walden"
#> 
#> $crossref
#> [1] "subugoe-collaborative.cr_instant"
#> 
#> $billing
#> [1] "subugoe-collaborative"
#> 
```
