# CLAUDE.md

R package **jnanalytics** (repo folder `jn_analytics`): open data about
the journal market in transformative agreements, hybrid and fully open
access. Successor of hoaddata 0.3 (`~/Documents/hoad/hoaddata`, kept
frozen); the dashboard is `~/Documents/hoad/hoaddash`. Design
background: `draft_implementation.md` (partly superseded by the
decisions below).

## Commands

``` r

devtools::load_all()                 # load the package
devtools::document()                 # after any roxygen change (run twice if links warn)
devtools::test()                     # tests; devtools::test(filter = "analysis")
devtools::check(args = "--no-manual")
source("data-raw/reference.R")       # rebuild the bundled reference tables
targets::tar_make()                  # full pipeline: reference -> BigQuery -> Parquet -> Hugging Face
pkgdown::build_site()                # website into docs/
```

## How the package is organised

- `inst/schema/columns.csv` is the single source of truth for every
  table’s columns, types, keys and descriptions. It feeds
  [`jn_validate()`](https://njahn82.github.io/jn_analytics/reference/jn_validate.md),
  the Rd `@format` sections, the BigQuery column descriptions and the
  Parquet metadata. Edit it with a CSV writer (Python `csv` or R), never
  by string replacement: a comma in an unquoted description breaks the
  file.
- `inst/sql/*.sql` are BigQuery templates with `{{dataset}}`,
  `{{openalex}}`, `{{crossref}}`, `{{year_min}}`, `{{year_max}}`,
  rendered by
  [`jn_sql()`](https://njahn82.github.io/jn_analytics/reference/jn_sql.md).
  Tests check that each template returns the schema’s columns in order.
- `_targets.R` is the build pipeline; `R/build.R`, `R/publish.R` the
  build functions; `R/analysis.R`, `R/source.R` the analysis layer
  (dplyr on Parquet via arrow, or BigQuery via dbplyr).
- `data-raw/`: the JCT files (`jct_jn_all.csv`, stored gzipped as
  `jct_jn_all.csv.gz`, `jct_inst_all.csv`, `esac_df.csv`) are copied in
  **by hand** from `~/Documents/r-tools/jct_data/data`
  (github.com/njahn82/jct_data). Do not add automatic fetching.
  `legacy/` holds hoaddata 0.3 inputs, `manual/` curated lookups,
  `diagnostics/` generated reports.

## BigQuery rules

- Inputs: only `subugoe-collaborative.cr_instant` (Crossref) and
  `subugoe-collaborative.openalex_walden` (OpenAlex). Output:
  `subugoe-collaborative.jn_analytics`. Other datasets
  (e.g. `oa2020.b18_*`) are examples at most; do not build on them.
- Always dry-run first and tell the user the GB and cost; get their OK
  before billed queries or table builds. Full rebuild is about 245 GB;
  `articles` alone about 140 GB. Never query the Crossref `reference`
  array (about 480 GB); use `reference_count`.
- Auth:
  [`jn_bq_auth()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_auth.md)
  (service-account key in CI, cached login locally).

## Decisions already made (do not re-open without the user)

- JCT is the only journal and agreement source; OAM was removed.
- OpenAlex is the spine (works, types, journal, ISSN-L, OA status);
  Crossref is joined by DOI only (no date filter) for CC licence and
  metadata indicators. Years come from OpenAlex; `pub_year_crossref` is
  for comparison.
- All works with a DOI from 2016 on are kept; filter on `work_type`
  (research = `article`, `review`). No supplement or paratext filters in
  SQL.
- CC licence counts for the version of record whatever `delay_in_days`
  (the delay filter was too strict and lost ~120k fully OA works in 2025
  alone); only accepted-manuscript licences are excluded, plus
  hoaddata’s delayed-OA exception for four journals.
- OA: every work in a fully OA journal-year is OA (share 100%); in a
  hybrid journal-year, OA = CC licence in Crossref. `articles_oa` counts
  both; `articles_with_cc_license` is the Crossref licence evidence
  alone (a metadata indicator in fully OA journals).
- Country-agnostic: no `scope`; country tables use full counting.
- `oa_model` per year: hybrid up to and including the OpenAlex
  `oa_flip_year`, fully OA afterwards. Publisher-wide flips (ACM
  from 2026) are curated in `data-raw/manual/oa_flips.csv`.
- For the dashboard’s drill-downs: `agreement_articles` (one row per
  eligible work, agreement, institution and role, with OA status;
  clustered and sorted by `agreement_id`, `ror`) and
  `agreement_institution_year` (its sums per institution). Works go to
  their closest matches only (direct or child participants; otherwise
  once to the umbrella organisation), never to every institute below an
  umbrella.
- Agreement coverage: first author; `direct`, `child` and `parent` ROR
  matches count, a `parent` only if the agreement lists at least two
  institutions whose only parent it is (else `parent_single`,
  e.g. European XFEL’s shareholders, universities with CSIC joint
  institutes); `parent_single` and `related` are stored but not counted;
  the period is checked with the OpenAlex publication date only.
- Participating institutions come from the JCT, corrected where it is
  wrong in `data-raw/manual/institution_corrections.csv` (with source).
- `portfolios` is one row per page and agreement (`agreement_id` = ESAC
  ID); a page’s journals come from `agreement_journals`. The ESAC IDs
  per page are essential to the user.
- Statistics per ESAC ID are journal-level (all works in the agreement’s
  journals, during the agreement period by default):
  `jn_oa(by = "agreement_id")`, `agreement =` filter. Author-matched
  coverage is the separate `agreement_journal_year` table.
- Analysis functions default to all journals (`oa_model = NULL`).
- All tables are published as Parquet in the Hugging Face dataset
  `najkoja/jn_analytics` (GitHub stays `njahn82/jn_analytics`), uploaded
  by
  [`jn_upload_hf()`](https://njahn82.github.io/jn_analytics/reference/jn_upload_hf.md)
  in the pipeline with the `HF_TOKEN` secret. Each release is a commit
  tagged with its build date (`release$snapshot_date`). `parquet/` is
  the local export folder and is not in git (older exports stay in the
  git history).
- Article tables are partitioned by `pub_year` in BigQuery and exported
  as one file per year (`articles/articles_2025.parquet`);
  `article_first_authors` and `article_agreements` carry `pub_year` for
  this.
- Users get the data with
  [`jn_download()`](https://njahn82.github.io/jn_analytics/reference/jn_download.md)
  (folder `my_data` by default, `jn_release.json` records
  release/commit/frozen; updates unless frozen; skips the large article
  tables by default) and get its
  [`jn_source()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md).
- BigQuery access through bigrquery only (no bigrquerystorage).
- The `build` workflow is started by hand (roughly quarterly); no cron.

## Conventions

- Function prefix `jn_`; internal helpers have no roxygen docs.
- Base pipe `|>`;
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  with `call =` pointing to the user-facing function.
- Tests mirror `R/` files; errors are tested with
  `expect_snapshot(error = TRUE)`; prefer specific expectations over
  `expect_true()`.
- Every user-facing change gets a `NEWS.md` bullet; new exported topics
  go into `_pkgdown.yml`.
- Keep references to “hoaddata 0.3” where they describe data provenance.
