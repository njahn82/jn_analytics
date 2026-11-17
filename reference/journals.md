# Journals

One row per journal covered by a transformative agreement in the
cOAlition S Journal Checker Tool (JCT).

## Usage

``` r
journals
```

## Format

A tibble with 6 columns:

- `issn_l` (string, key): Linking ISSN

- `title` (string): Journal title (OpenAlex, else the Journal Checker
  Tool)

- `publisher` (string): Normalised publisher name, e.g. `Wiley`

- `oa_model` (string): Current OA model: `hybrid` or `full_oa` (fully
  open access, according to OpenAlex or the curated list); `NA` = not in
  OpenAlex. The aggregates carry a year-aware `oa_model` that uses
  `oa_flip_year`

- `oa_flip_year` (integer): Year the journal became fully OA according
  to OpenAlex; `NA` if unknown or never. This and earlier years count as
  hybrid in the aggregates

- `openalex_source_id` (string): OpenAlex source ID

## Source

cOAlition S Journal Checker Tool, ESAC Transformative Agreement
Registry, OpenAlex.

## Details

`oa_model` distinguishes hybrid from fully open access journals.
Journals in the curated list `data-raw/manual/oa_model.csv` keep its
value; the others are `full_oa` if OpenAlex marks the journal as open
access or in DOAJ, and `hybrid` otherwise. Title, OpenAlex ID and
`oa_flip_year` come from OpenAlex. `publisher` is the most frequent
normalised publisher among the agreements that cover the journal.

## See also

Other reference tables:
[`agreement_institutions`](https://njahn82.github.io/jn_analytics/reference/agreement_institutions.md),
[`agreement_journals`](https://njahn82.github.io/jn_analytics/reference/agreement_journals.md),
[`agreements`](https://njahn82.github.io/jn_analytics/reference/agreements.md),
[`journal_issns`](https://njahn82.github.io/jn_analytics/reference/journal_issns.md),
[`portfolios`](https://njahn82.github.io/jn_analytics/reference/portfolios.md)
