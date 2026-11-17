# jnanalytics

Open data about the journal market in transformative agreements: which
journals are covered, whether they are hybrid or fully open access, how
much they publish, how much of it is openly licensed, how complete the
metadata is, and how many articles fall under an agreement.

jnanalytics succeeds [hoaddata](https://github.com/subugoe/hoaddata). It
builds one tidy data model in Google BigQuery from two open sources
only, [Crossref](https://www.crossref.org/) and
[OpenAlex](https://openalex.org/), using the journal and institution
lists of the cOAlition S [Journal Checker
Tool](https://journalcheckertool.org/) and the [ESAC
registry](https://esac-initiative.org/about/transformative-agreements/agreement-registry/).
The dashboard, a browser-based data explorer and BigQuery users all read
the same tables.

## Installation

From a clone of the repository:

``` r

devtools::install()
```

## Three ways to the data

| Layer | Tables | How |
|----|----|----|
| Package data | Reference tables: `journals`, `journal_issns`, `agreements`, `agreement_journals`, `agreement_institutions`, `portfolios` | [`library(jnanalytics)`](https://github.com/njahn82/jn_analytics) |
| Parquet export | Reference tables and journal-level aggregates (about 50 MB), in `parquet/` of this repository, one version per release | `jn_source("parquet")` in a clone, or download single files |
| BigQuery `subugoe-collaborative.jn_analytics` | All tables, including the article level | `jn_source("bigquery")` |

## Examples

The analysis functions run unchanged on the Parquet files and on
BigQuery. By default they count research articles (OpenAlex types
`article` and `review`) in all journals.

``` r

library(jnanalytics)
src <- jn_source("parquet")

# Open access in hybrid and fully OA journals over time
jn_oa(src, by = c("pub_year", "oa_model"))

# Licences in the hybrid journals of the Wiley portfolio, German first authors
jn_licenses(src, portfolio = "wiley", country = "DE", oa_model = "hybrid")

# Crossref metadata coverage by OA model
jn_metadata(src, by = c("pub_year", "oa_model"))

# Article-level data is only in BigQuery
bq <- jn_source("bigquery")
jn_tbl(bq, "articles") |>
  dplyr::filter(issn_l == "0360-0300", pub_year == 2025) |>
  dplyr::collect()
```

## Data model

Every table, column and counting rule is documented in one schema
(`inst/schema/columns.csv`), available as
[`jn_schema()`](https://njahn82.github.io/jn_analytics/reference/jn_schema.md)
and described in
[`vignette("data-model")`](https://njahn82.github.io/jn_analytics/articles/data-model.md).
The same descriptions are set on the BigQuery columns and stored in the
Parquet metadata.

## Building the data

The build is a [targets](https://docs.ropensci.org/targets/) pipeline
(`_targets.R`) that only reruns steps whose inputs changed:

1.  Copy the current JCT files (`jct_jn_all.csv`, `jct_inst_all.csv`,
    `esac_df.csv`) from the
    [jct_data](https://github.com/njahn82/jct_data) scraper into
    `data-raw/`, and gzip the journal list
    (`gzip -9 data-raw/jct_jn_all.csv`).
2.  Run
    [`targets::tar_make()`](https://docs.ropensci.org/targets/reference/tar_make.html)
    locally, or start the `build` workflow in GitHub Actions.

The pipeline rebuilds the reference tables, the BigQuery tables and the
Parquet export as needed. The workflow commits the updated reference
data and Parquet files, so every release is versioned in this
repository. A full rebuild scans about 245 GB in BigQuery.

## Development note

This package was developed with the help of [Claude
Code](https://claude.com/claude-code), Anthropic’s AI coding assistant.
Design decisions, counting rules and results were specified and reviewed
by the maintainer; the data were checked against the previous hoaddata
release.

## License

Data and code are released under CC0.
