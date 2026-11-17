# HOAD data model (draft)

Oct 28, 2026 · @Najko Jahn

## Why and principles

The proposal: one R package builds a set of tidy, consistently named
tables in BigQuery, and the dashboard, a browser-based data explorer and
BigQuery users all read those same tables. Today the tables are shaped
around the dashboard, so other users have to rebuild its logic.

Problems in the current hoaddata:

- Which journals belong to a publisher page lives in the Quarto code
  (`params$issn_l`, `config.csv`), not in the data.
- The same concept has different names: `vertrag` vs. `esac_publisher`,
  `article_total` vs. `articles_total` vs. `jn_all`.
- `jn_aff` repeats `articles_total` on every licence row and counts
  countries fully, which invites wrong sums.
- Several tables lack column docs; the docs still say 2017–2022 while
  the data runs to 2026.
- Millions of rows ship inside an R package as `.rda`, usable only from
  R.

Principles:

1.  **One source of truth.** All tables are built in BigQuery by one
    pipeline; everything else reads from it.
2.  **Reference tables separate from counts.** Journals and agreements
    are described once; counts point to them by `issn_l`.
3.  **Long format, additive counts.** Every count can be summed safely
    within its grain; shares are computed, not stored.
4.  **Same name, same meaning, everywhere.** English, snake_case, one
    name per concept.
5.  **Documentation lives with the data.** Column descriptions in
    BigQuery, copied into the Parquet export and the package docs.

## Overview

\[embedded content: HOAD data model · 10 tables in 3 groups\]

Reference tables describe journals and agreements once. Article tables
hold the facts, and the aggregates are built from them for the dashboard
and quick analyses.

## Reference tables

Five small tables describe journals, agreements and dashboard pages.
Every other table joins to them by `issn_l`, so filtering by publisher
or agreement becomes one join instead of dashboard code.

**`journals`**: one row per hybrid journal.

| Column               | Type        | Description                             |
|----------------------|-------------|-----------------------------------------|
| `issn_l`             | string, key | Linking ISSN                            |
| `title`              | string      | Journal title (Crossref, else OpenAlex) |
| `publisher`          | string      | Normalised publisher name, e.g. `Wiley` |
| `openalex_source_id` | string      | OpenAlex source ID                      |
| `cr_journal_id`      | string      | Crossref journal ID                     |

**`journal_issns`**: one row per ISSN.

| Column   | Type        | Description                |
|----------|-------------|----------------------------|
| `issn`   | string, key | Any ISSN of the journal    |
| `issn_l` | string      | Linking ISSN it belongs to |

**`agreements`**: one row per transformative agreement.

| Column | Type | Description |
|----|----|----|
| `agreement_id` | string, key | ESAC ID (JCT) or an OAM-based ID |
| `agreement_name` | string | e.g. `Wiley Hybrid (DEAL)` |
| `publisher` | string | Same names as in `journals` |
| `source` | string | `jct` or `oam` |
| `country` | string | ISO-2 country of the consortium, if national |
| `lead_institution` | string | Consortium lead, e.g. `MPDL` |

**`agreement_journals`**: which journals each agreement covers.

| Column         | Type   | Description    |
|----------------|--------|----------------|
| `agreement_id` | string | → `agreements` |
| `issn_l`       | string | → `journals`   |

**`portfolios`**: the dashboard pages, replacing `config.csv`. One row
per page and journal.

| Column            | Type   | Description                 |
|-------------------|--------|-----------------------------|
| `portfolio_id`    | string | Page slug, e.g. `wiley-jct` |
| `portfolio_label` | string | Page title, e.g. `Wiley`    |
| `collection`      | string | `jct` or `oam`              |
| `issn_l`          | string | → `journals`                |

## Article-level tables

All articles in hybrid journals, not only OA ones, with OA status and
metadata flags on each row. Every aggregate below can then be rebuilt
from these two tables, which makes the dashboard reproducible.

**`articles`**: one row per article (after excluding paratext,
supplements and corrections).

| Column | Type | Description |
|----|----|----|
| `doi` | string, key | DOI, lowercase |
| `issn_l` | string | → `journals` |
| `pub_year` | integer | Earliest publication year (Crossref `issued`) |
| `cc_license` | string | Normalised CC licence from Crossref; `NULL` = no CC licence |
| `is_oa_crossref` | boolean | CC licence in Crossref metadata |
| `is_oa_unpaywall` | boolean | Hybrid OA according to Unpaywall via OpenAlex |
| `has_tdm_link` | boolean | Full-text (TDM) link in Crossref |
| `has_orcid` | boolean | At least one ORCID in Crossref |
| `has_funder` | boolean | Funding metadata in Crossref |
| `has_abstract` | boolean | Open abstract in Crossref |
| `has_references` | boolean | Open reference list in Crossref |

**`article_first_authors`**: one row per article and first-author
affiliation.

| Column | Type | Description |
|----|----|----|
| `doi` | string | → `articles` |
| `ror` | string | ROR ID, full URL |
| `country_code` | string | ISO-2, uppercase |
| `country_source` | string | `openalex` or `extracted` (from the affiliation string) |

An article with two first-author countries has two rows here. Counting
by country is therefore full counting, which the column docs must say.

## Aggregate tables

Three aggregate tables replace `jn_ind`, `jn_aff`, `cr_upw` and `cr_md`.
They are derived from the article tables, small enough for the dashboard
and the browser, and every count column can be summed within its grain.

**`journal_year`**: one row per journal, year and scope.

| Column | Type | Description |
|----|----|----|
| `issn_l` | string | → `journals` |
| `pub_year` | integer | Publication year |
| `scope` | string | `global`, or an ISO-2 code for articles whose first author is in that country (today: `DE`) |
| `articles` | integer | All articles |
| `articles_oa` | integer | OA by Crossref CC licence |
| `articles_oa_unpaywall` | integer | OA according to Unpaywall |
| `articles_with_tdm_link` | integer | With full-text links |
| `articles_with_orcid` | integer | With at least one ORCID |
| `articles_with_funder` | integer | With funding metadata |
| `articles_with_abstract` | integer | With open abstract |
| `articles_with_references` | integer | With open reference list |

**`journal_year_country_license`**: one row per journal, year,
first-author country and licence.

| Column         | Type    | Description                            |
|----------------|---------|----------------------------------------|
| `issn_l`       | string  | → `journals`                           |
| `pub_year`     | integer | Publication year                       |
| `country_code` | string  | First author’s country (full counting) |
| `cc_license`   | string  | CC licence; `NULL` = not OA            |
| `articles`     | integer | Articles in this group                 |

**`journal_year_license`**: one row per journal, year, scope and
licence. Replaces the licence split in `jn_ind`.

| Column       | Type    | Description                             |
|--------------|---------|-----------------------------------------|
| `issn_l`     | string  | → `journals`                            |
| `pub_year`   | integer | Publication year                        |
| `scope`      | string  | `global` or ISO-2, as in `journal_year` |
| `cc_license` | string  | CC licence; `NULL` = not OA             |
| `articles`   | integer | Articles in this group                  |

None of these tables repeats a total on each row. A group’s total is
`SUM(articles)` over all licence rows, including `NULL`. Only the
country table uses full counting, so journal totals always come from
`journal_year`.

## Naming conventions

One name per concept, the same in BigQuery, Parquet, R and the docs.

| Rule | Example | Instead of |
|----|----|----|
| English, snake_case | `agreement_name` | `vertrag` |
| Counts start with `articles` | `articles`, `articles_oa`, `articles_with_orcid` | `article_total`, `articles_total`, `jn_all`, `cc_total` |
| Booleans start with `is_` or `has_` | `is_oa_crossref`, `has_orcid` | `tdm_total` at article level |
| One year column | `pub_year` | `cr_year` |
| Licences as plain strings from a fixed set, `NULL` = none | `CC BY-NC-ND` | ordered factor in one table, string in another |
| Shares are not stored | compute `articles_oa / articles` | `prop` |
| Identifiers in one canonical form | `doi` lowercase, `ror` full URL, `country_code` ISO-2 uppercase | mixed |
| Table names say their grain | `journal_year_license` | `jn_ind` |

Each release also gets a small `release` table: version, snapshot date,
source snapshots (Crossref, OpenAlex, JCT, OAM) and the date range
covered.

## From current hoaddata to the new model

Every current table has a successor; nothing is lost, and the dashboard
logic moves into `portfolios`.

| Current table | Rows today | Becomes | Note |
|----|----|----|----|
| `jct_hybrid_jns` | 721,388 | `agreements`, `agreement_journals`, `journal_issns` | One row per ISSN and agreement today; split into three |
| `oam_hybrid_jns` | 14,603 | `agreements`, `agreement_journals`, `journal_issns` | `vertrag` → `agreement_name`, `source = 'oam'` |
| `jct_oalex_venues` | not checked | `journals` | Title and OpenAlex IDs |
| `config.csv` (hoaddash) | 38 | `portfolios` | Page list moves from the dashboard repo into the data |
| `cc_articles` | 3,448,001 | `articles` + `article_first_authors` | Extended to all articles, not only OA |
| `jn_ind` | not checked | `journal_year` (totals) + `journal_year_license` | `prop` dropped |
| `jn_aff` | 3,093,418 | `journal_year_country_license` | Repeated `articles_total` dropped |
| `cr_upw` | 202,097 | `journal_year` (`articles_oa`, `articles_oa_unpaywall`) | `cat` → `scope` |
| `cr_md` | 138,341 | `journal_year` (`articles_with_*`) | `cat` → `scope` |

Row counts are from the `hoaddata` package data as of today. For the R
package, a `v1` compatibility layer could rebuild the old table shapes
from the new tables for one release.

## R package and pipeline

One R package triggers the whole build, ships the journal and agreement
data, and holds the analysis functions for global and portfolio views.
GitHub Actions only calls it.

| Part | Content |
|----|----|
| Bundled data | `journals`, `journal_issns`, `agreements`, `agreement_journals`, `portfolios`; small, documented with roxygen |
| Pipeline functions | `hoad_update_reference()`, `hoad_build()`, `hoad_publish()` |
| Analysis functions | e.g. `hoad_oa(portfolio = NULL, scope = "global", by = "pub_year")` |
| SQL | `inst/sql/`: article tables first, then journal-level aggregates |

Build steps, orchestrated with the `targets` package so only changed
steps rerun:

1.  **Update reference data.** Pull the JCT and OAM lists and rebuild
    the bundled reference tables.
2.  **Build in BigQuery.** Upload the reference tables, run `inst/sql/`
    to create the article tables and journal-level aggregates in
    `subugoe-collaborative.hoaddata`, and set column descriptions.
3.  **Export aggregates.** Write the reference tables, journal-level
    aggregates and `release` table as Parquet into the dashboard’s
    `docs/data/` folder.
4.  **Render the dashboard.** Quarto pages call the package’s analysis
    functions, so dashboard, package and explorer show the same numbers.

Global and portfolio analyses share one set of functions:
`portfolio = NULL` covers all hybrid journals, `portfolio = "wiley-jct"`
filters via the bundled `portfolios`. Written in dplyr, they run on
local Parquet through DuckDB or on BigQuery through `dbplyr`.

| Audience | Layer | Data |
|----|----|----|
| Everyone | Dashboard | Journal-level aggregates, rendered as pages |
| Advanced users | Data explorer (DuckDB in the browser) | Reference tables + journal-level aggregates |
| Replication, article- and institution-level work | BigQuery (+ MCP) | All tables including article level, plus the SQL that builds them |

## Data explorer

A dashboard page runs DuckDB in the visitor’s browser and queries the
journal-level Parquet files directly: no server, no API keys, and the
same data version as the dashboard. Article-level data stays in
BigQuery.

- **Technology:** Quarto’s Observable JS cells, which include
  DuckDB-WASM (`DuckDBClient`).
- **Interface:** a SQL box, ready-made queries for the global view and
  each portfolio (generated from `portfolios`), a results table and a
  CSV download.
- **Data offered:** reference tables, `journal_year`,
  `journal_year_license`, `journal_year_country_license` and `release`.
  Not offered: `articles`, `article_first_authors`.
- **Hosting:** Parquet files in `docs/data/`, published with the
  dashboard on GitHub Pages. The data stays in the GitHub repo; no
  separate hosting service is needed.

Size is no problem today. The current `jn_aff` (3.1M rows) is 12.7 MB as
zstd-compressed Parquet; `cr_upw` and `cr_md` are about 1 MB each.
GitHub Pages allows 100 MB per file. If `journal_year_country_license`
grows towards that, it can be split into one file per year without
changing the queries.

## Open questions

**All articles or only OA?** Publishing every article (not only OA)
makes the aggregates reproducible, but enlarges the data. Do the
Crossref-derived article rows raise any redistribution concerns?

**Renaming `cr_year` to `pub_year`.** Clearer, but breaks existing code.
Keep the old names in a compatibility layer for one release?

**Agreement membership over time.** Journals enter and leave agreements.
Is a current snapshot enough, or do we need `valid_from` / `valid_to` in
`agreement_journals`?

**Publisher names.** Who maintains the normalised `publisher` list, and
does it follow ESAC or Crossref names?

**Corresponding authors.** First author stands in for the corresponding
author today. Check whether OpenAlex now offers usable
corresponding-author data for a second scope.

**Scopes beyond Germany.** `scope` allows other countries; which ones,
if any, for the next release?

**Release cadence and versioning.** Monthly with the dashboard build?
Keep older releases as Parquet files in the repo, in BigQuery, or both?

**Where the counting rules live.** Paratext, supplement and correction
exclusion should exist in one SQL step only. Is that already the case?

**Package name.** Keep `hoaddata`, with a new major version, or start a
new package such as `hoad`?
