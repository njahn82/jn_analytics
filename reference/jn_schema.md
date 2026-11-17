# Column schema of the jnanalytics data model

Returns the column definitions of all tables in the jnanalytics data
model. The schema is the single source of truth for column names, types
and descriptions: it is used to validate tables, to document the bundled
data and to set column descriptions in BigQuery and Parquet.

## Usage

``` r
jn_schema(table = NULL)
```

## Arguments

- table:

  Optional table name. If `NULL`, the columns of all tables are
  returned.

## Value

A tibble with the columns `table`, `column`, `type`, `key`, `references`
and `description`.

## Examples

``` r
jn_schema("journals")
#> # A tibble: 6 × 6
#>   table    column             type    key   references description              
#>   <chr>    <chr>              <chr>   <lgl> <chr>      <chr>                    
#> 1 journals issn_l             string  TRUE  ""         Linking ISSN             
#> 2 journals title              string  FALSE ""         Journal title (OpenAlex,…
#> 3 journals publisher          string  FALSE ""         Normalised publisher nam…
#> 4 journals oa_model           string  FALSE ""         Current OA model: `hybri…
#> 5 journals oa_flip_year       integer FALSE ""         Year the journal became …
#> 6 journals openalex_source_id string  FALSE ""         OpenAlex source ID       
```
