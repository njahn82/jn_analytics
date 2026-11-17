# Download the data

The reference tables and journal-level aggregates are published as
[Parquet](https://parquet.apache.org/) files with every release. They
are kept in the
[`parquet/`](https://github.com/njahn82/jn_analytics/tree/main/parquet)
folder of the repository and can be read without an account or API key,
in R, Python, DuckDB or any other tool that reads Parquet. Article-level
tables (`articles`, `article_first_authors`, `article_agreements`) are
only in BigQuery, `subugoe-collaborative.jn_analytics`.

Data and code are released under CC0.

## Current release

| Item              | Value      |
|:------------------|:-----------|
| Version           | 0.1.0.9000 |
| Built             | 2026-11-17 |
| Crossref snapshot | 2026/09    |
| OpenAlex snapshot | 2026-10-14 |
| JCT snapshot      | 2026-11-09 |
| Publication years | 2016–2026  |

The links below always point to the latest release. Earlier releases are
in the [history of
`parquet/`](https://github.com/njahn82/jn_analytics/commits/main/parquet).

## Files

| Table | Rows | Size | Download |
|:---|---:|---:|:---|
| [`journals`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journals) | 19,401 | 0.5 MB | [journals.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/journals.parquet) |
| [`journal_issns`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journal-issns) | 35,190 | 0.4 MB | [journal_issns.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/journal_issns.parquet) |
| [`agreements`](https://njahn82.github.io/jn_analytics/articles/data-model.html#agreements) | 1,510 | \< 0.1 MB | [agreements.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/agreements.parquet) |
| [`agreement_journals`](https://njahn82.github.io/jn_analytics/articles/data-model.html#agreement-journals) | 713,925 | 0.9 MB | [agreement_journals.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/agreement_journals.parquet) |
| [`agreement_institutions`](https://njahn82.github.io/jn_analytics/articles/data-model.html#agreement-institutions) | 39,783 | 0.4 MB | [agreement_institutions.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/agreement_institutions.parquet) |
| [`portfolios`](https://njahn82.github.io/jn_analytics/articles/data-model.html#portfolios) | 937 | \< 0.1 MB | [portfolios.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/portfolios.parquet) |
| [`journal_year`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journal-year) | 500,111 | 3.5 MB | [journal_year.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/journal_year.parquet) |
| [`journal_year_country`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journal-year-country) | 3,812,236 | 23.5 MB | [journal_year_country.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/journal_year_country.parquet) |
| [`journal_year_license`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journal-year-license) | 746,039 | 1.8 MB | [journal_year_license.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/journal_year_license.parquet) |
| [`journal_year_country_license`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journal-year-country-license) | 4,580,411 | 15.4 MB | [journal_year_country_license.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/journal_year_country_license.parquet) |
| [`agreement_journal_year`](https://njahn82.github.io/jn_analytics/articles/data-model.html#agreement-journal-year) | 1,132,600 | 3.6 MB | [agreement_journal_year.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/agreement_journal_year.parquet) |
| [`release`](https://njahn82.github.io/jn_analytics/articles/data-model.html#release) | 1 | \< 0.1 MB | [release.parquet](https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/release.parquet) |

Every table and column is described in the [data
model](https://njahn82.github.io/jn_analytics/articles/data-model.md),
including the counting rules. Two matter most when working with the
files:

- Counts can be summed over journals, years and work types; compute
  shares from the sums. Filter `work_type` to `article` and `review` for
  research articles.
- The country tables count a work once per first-author country (full
  counting). Take totals from `journal_year`, never by summing over
  countries.

## Usage

### R, with jnanalytics

Download all files into one folder and use the analysis functions:

``` r

library(jnanalytics)

base_url <- "https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/"
files <- paste0(c(jn_publish_tables(), "release"), ".parquet")
dir.create("jn_parquet")
for (f in files) {
  download.file(paste0(base_url, f), file.path("jn_parquet", f), mode = "wb")
}

src <- jn_source("jn_parquet")
jn_oa(src, by = c("pub_year", "oa_model"))
```

### R, with arrow

``` r

download.file(
  "https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/journal_year.parquet",
  "journal_year.parquet", mode = "wb"
)
journal_year <- arrow::read_parquet("journal_year.parquet")
```

### Python

``` python
import pandas as pd

url = "https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/journal_year.parquet"
journal_year = pd.read_parquet(url)
```

### DuckDB

DuckDB reads the files directly from their URL:

``` sql
SELECT pub_year, oa_model,
       sum(articles) AS articles,
       sum(articles_oa) / sum(articles) AS share_oa
FROM 'https://raw.githubusercontent.com/njahn82/jn_analytics/main/parquet/journal_year.parquet'
WHERE work_type IN ('article', 'review')
GROUP BY ALL
ORDER BY ALL;
```

## Column descriptions in the files

Each file carries its column descriptions as JSON in the Parquet
metadata (`jn_columns`), together with the table name (`jn_table`) and
the package version (`jn_version`):

``` r

meta <- arrow::open_dataset("journal_year.parquet")$schema$metadata
jsonlite::fromJSON(meta$jn_columns)
```
