# Plan: all jnanalytics tables on Hugging Face

Status (2026-11-18): setup done; the code changes (steps 1-8 in the
package) are done, untested against BigQuery and Hugging Face. Still to
do: dry-run and rebuild of the article tables, export and first upload
(step 9).

## Goal

One place for the open data: all 15 tables of
`subugoe-collaborative.jn_analytics` as Parquet in one Hugging Face
dataset repository, versioned per release. The Parquet files are no
longer committed to git. The download page, the examples and later the
hoaddash dashboard read from Hugging Face.

## Decisions

- **All tables on Hugging Face**: the six reference tables, the five
  journal-level aggregates, `release`, and the article tables
  `articles`, `article_first_authors` and `article_agreements`.
- **One source**: `parquet/` stops being committed to git. Older
  versions stay in the git history.
- **Licence**: CC0, as for the package. OpenAlex is CC0; the Crossref
  metadata used has no reuse restrictions (abstracts are not included,
  only `has_abstract`).
- **Namespace** (2026-11-18): `najkoja/jn_analytics` on Hugging Face
  (personal account; the GitHub repository stays
  `njahn82/jn_analytics`).
- **Release tags** (2026-11-18): the build date, e.g. `2026-11-17`, the
  same date as in the `release` table.
- **`pub_year` column** (2026-11-18): `article_first_authors` and
  `article_agreements` get a `pub_year` column (taken from `articles`,
  i.e. the OpenAlex publication year), so all three article tables can
  be partitioned and exported by year.

## Open decisions

1.  **DOI**: Hugging Face can mint a DOI for a public dataset; minting
    is a manual step per release. Decide later which releases get one.

## Setup (done 2026-11-18)

1.  Public dataset repository `najkoja/jn_analytics` created (CC0, not
    gated).
2.  Fine-grained token with read and write access to that repository
    only, stored as the GitHub secret `HF_TOKEN` in
    `njahn82/jn_analytics`.
3.  Local: `hf` CLI 2.4.0 via Homebrew, logged in as `najkoja` for the
    first upload.

## Layout of the dataset repository

``` text
README.md                         dataset card (generated)
release.parquet
journals.parquet
journal_issns.parquet
agreements.parquet
agreement_journals.parquet
agreement_institutions.parquet
portfolios.parquet
journal_year.parquet
journal_year_country.parquet
journal_year_license.parquet
journal_year_country_license.parquet
agreement_journal_year.parquet
articles/articles_2016.parquet ... articles_<year_max>.parquet
article_first_authors/article_first_authors_2016.parquet ...
article_agreements/article_agreements_2016.parquet ...
```

- Article tables are split by publication year (about 50–100 MB per
  file; about 1.3 GB in total). Rows of `article_first_authors` and
  `article_agreements` are assigned to the year of their article.
- Every file carries the schema metadata as now (`jn_table`,
  `jn_version`, `jn_columns`), written by `write_jn_parquet()`.

## Implementation steps

1.  **Partition the article tables in BigQuery by `pub_year`**
    (`PARTITION BY RANGE_BUCKET(pub_year, GENERATE_ARRAY(2016, 2100, 1))`,
    or clustering if partitioning does not fit). Then exporting one year
    scans only that year, and users’ queries filtered by year get
    cheaper. `article_first_authors` and `article_agreements` get a new
    `pub_year` column (schema change in `inst/schema/columns.csv`, the
    SQL templates, the Rd `@format` sections and NEWS).
    - Needs a rebuild of the article tables (about 230 GB, about
      \$1.50); best combined with the next quarterly build. Dry-run
      first.
2.  **Export** (`R/publish.R`): extend
    [`jn_publish()`](https://njahn82.github.io/jn_analytics/reference/jn_publish.md)
    to write all tables into one folder in the layout above. Article
    tables are exported year by year with `bigrquery` (one query per
    year on the partitioned table, about 9 GB in total).
    [`jn_publish_tables()`](https://njahn82.github.io/jn_analytics/reference/jn_publish_tables.md)
    covers all 15 tables.
3.  **Dataset card** (new internal function, e.g. `jn_dataset_card()`):
    generated from
    [`jn_schema()`](https://njahn82.github.io/jn_analytics/reference/jn_schema.md)
    and the `release` table. YAML header with `license: cc0-1.0`,
    `pretty_name`, and one `configs` entry per table (with `data_files`
    patterns) so the Hugging Face viewer shows each table. Body: sources
    and snapshots, counting rules (link to the data-model page), file
    list, usage examples.
4.  **Upload**:
    `hf upload najkoja/jn_analytics <folder> . --repo-type dataset --commit-message "Release <date>"`,
    then tag the commit with the release date. Runs with the `HF_TOKEN`
    secret. Use `hf upload-large-folder` if uploads of the article files
    time out.
5.  **Pipeline** (`_targets.R`):
    - export target (format file) after the BigQuery steps, replacing
      `parquet`;
    - upload target that reruns only when the exported files changed.
6.  **Build workflow** (`build.yaml`): install the Hugging Face CLI
    (`pip install -U huggingface_hub`), pass `HF_TOKEN`, drop `parquet/`
    from the commit step. The check-only mode also checks the token
    (`hf auth whoami`).
7.  **Git**: add `parquet/` to `.gitignore` again and remove it from the
    index (`git rm -r --cached parquet`).
8.  **Docs**:
    - Download page (`vignettes/articles/data.Rmd`): links to
      `https://huggingface.co/datasets/najkoja/jn_analytics/resolve/main/<file>`;
      the release box and file table read `release.parquet` and the file
      list from Hugging Face at build time instead of `parquet/`. New
      section on the article tables.
    - Examples: DuckDB with
      `hf://datasets/najkoja/jn_analytics/articles/*.parquet`, Python
      (`pandas` or `datasets`), R (download, then
      [`jn_source()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md)).
    - README “Three ways to the data”, data-model vignette, CLAUDE.md
      decisions, NEWS.
    - Optional helper `jn_download(dir, tables)` that fetches files from
      Hugging Face into a folder for
      [`jn_source()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md).
9.  **First upload**: run the export and upload locally once (dry-run
    the BigQuery part first), check the dataset viewer and a DuckDB
    query, then switch the workflow.

## Costs

- Export of the article tables: about 9 GB with partitioning, a few
  cents. Without partitioning, one query per year would scan the whole
  table each time (about 50–70 GB in total).
- Hugging Face hosting of public datasets: free.

## Later

- hoaddash reads the aggregates from Hugging Face.
- Older releases: keep as tagged revisions on Hugging Face; readers can
  pin a release with `revision=<tag>` or `.../resolve/<tag>/<file>`.
