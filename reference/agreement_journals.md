# Journals covered by transformative agreements

Which journals each agreement covers. A journal covered by several
agreements appears once per agreement.

## Usage

``` r
agreement_journals
```

## Format

A tibble with 3 columns:

- `agreement_id` (string, key): → `agreements`

- `issn_l` (string, key): → `journals`

- `last_seen` (date): Date the journal was last listed for this
  agreement in the Journal Checker Tool; `NA` if only listed in archived
  JCT data (hoaddata 0.3)

## See also

Other reference tables:
[`agreement_institutions`](https://njahn82.github.io/jn_analytics/reference/agreement_institutions.md),
[`agreements`](https://njahn82.github.io/jn_analytics/reference/agreements.md),
[`journal_issns`](https://njahn82.github.io/jn_analytics/reference/journal_issns.md),
[`journals`](https://njahn82.github.io/jn_analytics/reference/journals.md),
[`portfolios`](https://njahn82.github.io/jn_analytics/reference/portfolios.md)
