# Institutions participating in transformative agreements

One row per agreement and participating institution, as listed in the
Journal Checker Tool, identified by ROR ID. In BigQuery,
`article_agreements` matches authors' institutions to these, including
their child and parent institutions. Institutions listed without a valid
ROR ID are not included.

## Usage

``` r
agreement_institutions
```

## Format

A tibble with 4 columns:

- `agreement_id` (string, key): → `agreements`

- `ror` (string, key): ROR ID of a participating institution as listed
  in the Journal Checker Tool or added by a curated correction
  (`data-raw/manual/institution_corrections.csv`), full URL

- `inst_name` (string): Institution name as listed in the Journal
  Checker Tool or in the curated correction

- `last_seen` (date): Date the institution was last listed for this
  agreement in the Journal Checker Tool; `NA` if only listed in archived
  JCT data (hoaddata 0.3) or added by a curated correction

## Source

cOAlition S Journal Checker Tool.

## See also

Other reference tables:
[`agreement_journals`](https://njahn82.github.io/jn_analytics/reference/agreement_journals.md),
[`agreements`](https://njahn82.github.io/jn_analytics/reference/agreements.md),
[`journal_issns`](https://njahn82.github.io/jn_analytics/reference/journal_issns.md),
[`journals`](https://njahn82.github.io/jn_analytics/reference/journals.md),
[`portfolios`](https://njahn82.github.io/jn_analytics/reference/portfolios.md)
