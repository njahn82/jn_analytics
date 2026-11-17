# Dashboard portfolios

The publisher pages of the dashboard, one row per page and agreement. A
portfolio is the set of transformative agreements of one publisher, so
`agreement_id` gives the ESAC IDs of a page. Its journals are those of
its agreements in
[agreement_journals](https://njahn82.github.io/jn_analytics/reference/agreement_journals.md).

## Usage

``` r
portfolios
```

## Format

A tibble with 3 columns:

- `portfolio_id` (string, key): Page slug, e.g. `wiley`

- `portfolio_label` (string): Page title, e.g. `Wiley`

- `agreement_id` (string, key): ESAC ID of an agreement on this page (→
  `agreements`). The page's journals are those of its agreements in
  `agreement_journals`

## See also

Other reference tables:
[`agreement_institutions`](https://njahn82.github.io/jn_analytics/reference/agreement_institutions.md),
[`agreement_journals`](https://njahn82.github.io/jn_analytics/reference/agreement_journals.md),
[`agreements`](https://njahn82.github.io/jn_analytics/reference/agreements.md),
[`journal_issns`](https://njahn82.github.io/jn_analytics/reference/journal_issns.md),
[`journals`](https://njahn82.github.io/jn_analytics/reference/journals.md)
