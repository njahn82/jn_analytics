# Download the data

All tables of jnanalytics are published as
[Parquet](https://parquet.apache.org/) files in the Hugging Face dataset
[`najkoja/jn_analytics`](https://huggingface.co/datasets/najkoja/jn_analytics):
the reference tables, the journal-level aggregates and the article
tables (`articles`, `article_first_authors`, `article_agreements`). They
can be read without an account or API key, in R, Python, DuckDB or any
other tool that reads Parquet. The same tables are in BigQuery,
`subugoe-collaborative.jn_analytics`.

Data and code are released under CC0.

## Current release

| Item              | Value      |
|:------------------|:-----------|
| Version           | 0.1.0.9000 |
| Built             | 2026-11-18 |
| Crossref snapshot | 2026/09    |
| OpenAlex snapshot | 2026-10-14 |
| JCT snapshot      | 2026-11-09 |
| Publication years | 2016–2026  |

The links below point to the latest release. Every release is a tagged
commit named after its build date. Read an earlier release with
`.../resolve/<date>/<file>` instead of `.../resolve/main/<file>`, or
with `--revision <date>` in `hf download`.

Releases: `2026-11-18`

## Files

| Table | Size | Download |
|:---|---:|:---|
| [`journals`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journals) | 0.5 MB | [journals.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/journals.parquet) |
| [`journal_issns`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journal-issns) | 0.4 MB | [journal_issns.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/journal_issns.parquet) |
| [`agreements`](https://njahn82.github.io/jn_analytics/articles/data-model.html#agreements) | \< 0.1 MB | [agreements.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/agreements.parquet) |
| [`agreement_journals`](https://njahn82.github.io/jn_analytics/articles/data-model.html#agreement-journals) | 0.9 MB | [agreement_journals.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/agreement_journals.parquet) |
| [`agreement_institutions`](https://njahn82.github.io/jn_analytics/articles/data-model.html#agreement-institutions) | 0.4 MB | [agreement_institutions.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/agreement_institutions.parquet) |
| [`portfolios`](https://njahn82.github.io/jn_analytics/articles/data-model.html#portfolios) | \< 0.1 MB | [portfolios.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/portfolios.parquet) |
| [`journal_year`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journal-year) | 3.4 MB | [journal_year.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/journal_year.parquet) |
| [`journal_year_country`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journal-year-country) | 23.5 MB | [journal_year_country.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/journal_year_country.parquet) |
| [`journal_year_license`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journal-year-license) | 2.3 MB | [journal_year_license.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/journal_year_license.parquet) |
| [`journal_year_country_license`](https://njahn82.github.io/jn_analytics/articles/data-model.html#journal-year-country-license) | 15.4 MB | [journal_year_country_license.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/journal_year_country_license.parquet) |
| [`agreement_journal_year`](https://njahn82.github.io/jn_analytics/articles/data-model.html#agreement-journal-year) | 3.6 MB | [agreement_journal_year.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/agreement_journal_year.parquet) |
| [`agreement_institution_year`](https://njahn82.github.io/jn_analytics/articles/data-model.html#agreement-institution-year) | 1.3 MB | [agreement_institution_year.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/agreement_institution_year.parquet) |
| [`articles`](https://njahn82.github.io/jn_analytics/articles/data-model.html#articles) | 385.1 MB | [articles/](https://huggingface.co/datasets/najkoja/jn_analytics/tree/main/articles) (11 files, one per year) |
| [`article_first_authors`](https://njahn82.github.io/jn_analytics/articles/data-model.html#article-first-authors) | 355.8 MB | [article_first_authors/](https://huggingface.co/datasets/najkoja/jn_analytics/tree/main/article_first_authors) (11 files, one per year) |
| [`article_agreements`](https://njahn82.github.io/jn_analytics/articles/data-model.html#article-agreements) | 109.4 MB | [article_agreements/](https://huggingface.co/datasets/najkoja/jn_analytics/tree/main/article_agreements) (10 files, one per year) |
| [`agreement_articles`](https://njahn82.github.io/jn_analytics/articles/data-model.html#agreement-articles) | 51.8 MB | [agreement_articles/](https://huggingface.co/datasets/najkoja/jn_analytics/tree/main/agreement_articles) (10 files, one per year) |
| [`release`](https://njahn82.github.io/jn_analytics/articles/data-model.html#release) | \< 0.1 MB | [release.parquet](https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/release.parquet) |

The article tables are split into one file per publication year
(`pub_year`), for example `articles/articles_2025.parquet`. Read a
single year, or the whole folder at once. For questions about one
agreement or institution, start with `agreement_institution_year`
(counts per participating institution) and `agreement_articles` (the
eligible works themselves, with journal, type and OA status, sorted by
agreement); both need no joins.

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

### DuckDB

DuckDB reads the files directly from Hugging Face, including all years
of an article table at once:

``` sql
SELECT pub_year, oa_model,
       sum(articles) AS articles,
       sum(articles_oa) / sum(articles) AS share_oa
FROM 'hf://datasets/najkoja/jn_analytics/journal_year.parquet'
WHERE work_type IN ('article', 'review')
GROUP BY ALL
ORDER BY ALL;

SELECT oa_status, count(*) AS n
FROM 'hf://datasets/najkoja/jn_analytics/articles/*.parquet'
WHERE pub_year = 2025 AND issn_l = '0360-0300'
GROUP BY ALL;
```

### R, with jnanalytics

Download the dataset with the [Hugging Face
CLI](https://huggingface.co/docs/huggingface_hub/guides/cli)
(`brew install hf` or `pipx install huggingface_hub`), all of it or only
some tables:

``` sh
hf download najkoja/jn_analytics --repo-type dataset --local-dir jn_data
hf download najkoja/jn_analytics --repo-type dataset --local-dir jn_data \
  --include "journal*.parquet" "agreement*.parquet" "portfolios.parquet" "release.parquet"
```

Then use the analysis functions; the article tables work too:

``` r

library(jnanalytics)
src <- jn_source("jn_data")
jn_oa(src, by = c("pub_year", "oa_model"))

jn_tbl(src, "articles") |>
  dplyr::filter(issn_l == "0360-0300", pub_year == 2025) |>
  dplyr::collect()
```

### R, with arrow

``` r

url <- "https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/journal_year.parquet"
download.file(url, "journal_year.parquet", mode = "wb")
journal_year <- arrow::read_parquet("journal_year.parquet")
```

### Python

With pandas and huggingface_hub installed:

``` python
import pandas as pd

journal_year = pd.read_parquet("hf://datasets/najkoja/jn_analytics/journal_year.parquet")
articles_2025 = pd.read_parquet("hf://datasets/najkoja/jn_analytics/articles/articles_2025.parquet")
```

Or with the datasets library, one configuration per table:

``` python
from datasets import load_dataset

journal_year = load_dataset("najkoja/jn_analytics", "journal_year")
```

## Column descriptions in the files

Each file carries its column descriptions as JSON in the Parquet
metadata (`jn_columns`), together with the table name (`jn_table`) and
the package version (`jn_version`):

``` r

meta <- arrow::open_dataset("journal_year.parquet")$schema$metadata
jsonlite::fromJSON(meta$jn_columns)
```
