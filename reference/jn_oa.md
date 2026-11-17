# Open access in the journal market

Counts works and open access works, and computes OA shares, for all
journals or a dashboard portfolio, hybrid or fully open access, globally
or for first-author countries. The same code runs on the Parquet export
and on BigQuery (see
[`jn_source()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md)).

## Usage

``` r
jn_oa(
  src = jn_source(),
  by = "pub_year",
  portfolio = NULL,
  agreement = NULL,
  agreement_period = TRUE,
  country = NULL,
  work_types = c("article", "review"),
  oa_model = NULL
)

jn_licenses(
  src = jn_source(),
  by = "pub_year",
  portfolio = NULL,
  agreement = NULL,
  agreement_period = TRUE,
  country = NULL,
  work_types = c("article", "review"),
  oa_model = NULL
)

jn_metadata(
  src = jn_source(),
  by = "pub_year",
  portfolio = NULL,
  agreement = NULL,
  agreement_period = TRUE,
  country = NULL,
  work_types = c("article", "review"),
  oa_model = NULL
)
```

## Arguments

- src:

  A
  [`jn_source()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md).
  Defaults to the Parquet files in `parquet/`.

- by:

  Columns to group by: any of `pub_year`, `issn_l`, `publisher`,
  `portfolio_id`, `agreement_id`, `oa_model`, `work_type`,
  `country_code`.

- portfolio:

  Portfolio IDs (see
  [portfolios](https://njahn82.github.io/jn_analytics/reference/portfolios.md))
  to restrict to, or `NULL` for all journals.

- agreement:

  ESAC IDs (see
  [agreements](https://njahn82.github.io/jn_analytics/reference/agreements.md))
  to restrict to the journals of these agreements, or `NULL`.

- agreement_period:

  With `agreement` or `"agreement_id"` in `by`: if `TRUE` (default),
  count a journal's works only in the years in which the agreement ran
  (by publication year; agreements without a period are left out). If
  `FALSE`, count all years.

- country:

  ISO-2 codes of first-author countries, or `NULL` for all works.

- work_types:

  OpenAlex work types to include; `NULL` for all. The default counts
  research articles.

- oa_model:

  `NULL` (default) for all journals, or `"hybrid"` and/or `"full_oa"` to
  restrict to these journals. Use `by = "oa_model"` to compare them. The
  OA model is taken per year: a journal that became fully OA in its
  OpenAlex `oa_flip_year` counts as hybrid up to and including that
  year, which is usually a transition year.

## Value

A tibble with the `by` columns, `articles`, `articles_oa`,
`articles_oa_openalex`, and the shares `share_oa` and
`share_oa_openalex`. `articles_oa` counts every work in a fully OA
journal-year and, in hybrid journal-years, works with a CC licence in
Crossref; fully OA journals therefore have `share_oa` 1. How many works
carry a CC licence in Crossref is in `jn_metadata()`
(`share_cc_license`) and `jn_licenses()`.

## Details

Statistics per agreement are journal-level: all works in the journals an
agreement covers, whoever the authors are. A journal covered by several
agreements counts in each of them, so results by `agreement_id` must not
be summed over agreements. Works matched to an agreement through their
authors' institutions are in the `agreement_journal_year` table.

Journal and country totals follow the counting rules of the data model:
without `country`, counts come from `journal_year` and every work counts
once. With `country`, or `"country_code"` in `by`, they come from the
country tables, where a work with first authors in several countries
counts once per country (full counting).

`jn_licenses()` splits works by CC licence in Crossref (`NA` = no CC
licence, which in a fully OA journal is a metadata gap, not closed
access); `share` is relative to all works in the `by` group.

`jn_metadata()` reports how many works carry each kind of Crossref
metadata, including a CC licence (`share_cc_license`). Shares are
relative to `articles_in_crossref`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Global trend of research articles, hybrid vs fully OA journals
jn_oa(by = c("pub_year", "oa_model"))

# Hybrid journals in the Wiley portfolio, German first authors, by licence
jn_licenses(portfolio = "wiley", country = "DE", oa_model = "hybrid")

# Top countries in 2025
jn_oa(by = "country_code") |> dplyr::filter(articles > 10000)

# OA in the journals of each Wiley agreement, during the agreement period
jn_oa(portfolio = "wiley", by = c("agreement_id", "pub_year"))
} # }
```
