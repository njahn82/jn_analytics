# Transformative agreements

One row per transformative agreement listed in the Journal Checker Tool,
identified by its ESAC ID. `country` is only set for national
agreements. Agreements missing from the ESAC registry get an inferred
period, flagged by `is_period_inferred`.

## Usage

``` r
agreements
```

## Format

A tibble with 8 columns:

- `agreement_id` (string, key): ESAC ID as used in the Journal Checker
  Tool

- `agreement_name` (string): `publisher (lead_institution)`, e.g.
  `Wiley (DEAL)`

- `publisher` (string): Same names as in `journals`

- `country` (string): ISO-2 country of the consortium, if national

- `lead_institution` (string): Consortium lead, e.g. `MPDL`

- `start_date` (date): Start of the agreement according to ESAC, or
  inferred (see `is_period_inferred`)

- `end_date` (date): End of the agreement according to ESAC, or inferred
  (see `is_period_inferred`)

- `is_period_inferred` (boolean): `TRUE` if the agreement is missing
  from ESAC and its period is inferred: from 1 January of the year in
  its ID to the end of the year it was last listed in the Journal
  Checker Tool

## Source

ESAC Transformative Agreement Registry
(<https://esac-initiative.org/about/transformative-agreements/agreement-registry/>).

## See also

Other reference tables:
[`agreement_institutions`](https://njahn82.github.io/jn_analytics/reference/agreement_institutions.md),
[`agreement_journals`](https://njahn82.github.io/jn_analytics/reference/agreement_journals.md),
[`journal_issns`](https://njahn82.github.io/jn_analytics/reference/journal_issns.md),
[`journals`](https://njahn82.github.io/jn_analytics/reference/journals.md),
[`portfolios`](https://njahn82.github.io/jn_analytics/reference/portfolios.md)
