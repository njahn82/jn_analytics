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

The first release on Hugging Face is in preparation.

The links below point to the latest release. Every release is a tagged
commit named after its build date. Read an earlier release with
`.../resolve/<date>/<file>` instead of `.../resolve/main/<file>`, or
with `--revision <date>` in `hf download`.

## Files

The article tables are split into one file per publication year
(`pub_year`), for example `articles/articles_2025.parquet`. Read a
single year, or the whole folder at once.

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
