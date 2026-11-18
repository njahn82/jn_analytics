# Tables in the jnanalytics data model

Tables in the jnanalytics data model

## Usage

``` r
jn_tables()
```

## Value

A character vector of table names, in the order of the schema.

## Examples

``` r
jn_tables()
#>  [1] "journals"                     "journal_issns"               
#>  [3] "agreements"                   "agreement_journals"          
#>  [5] "agreement_institutions"       "portfolios"                  
#>  [7] "articles"                     "article_first_authors"       
#>  [9] "article_agreements"           "journal_year"                
#> [11] "journal_year_country"         "journal_year_country_license"
#> [13] "agreement_journal_year"       "journal_year_license"        
#> [15] "release"                      "agreement_articles"          
#> [17] "agreement_institution_year"  
```
