# Build the reference tables

Rebuilds `journals`, `journal_issns`, `agreements`,
`agreement_journals`, `agreement_institutions` and `portfolios` from the
raw Journal Checker Tool (JCT) and ESAC files in `raw_dir`, validates
them against
[`jn_schema()`](https://njahn82.github.io/jn_analytics/reference/jn_schema.md)
and checks that every `issn_l` and `agreement_id` resolves.

## Usage

``` r
jn_update_reference(raw_dir = "data-raw", quiet = FALSE)
```

## Arguments

- raw_dir:

  Directory with the raw files.

- quiet:

  If `FALSE`, report coverage diagnostics.

## Value

A named list of six tibbles, plus a `diagnostics` element listing
journal-list rows without ISSN-L and institutions without ROR ID.

## Details

Expected files in `raw_dir` (see `data-raw/README.md`):

- `jct_jn_all.csv.gz`, `esac_df.csv`: current JCT journal lists and the
  ESAC registry.

- `jct_inst_all.csv`, `legacy/jct_institutions.csv`: participating
  institutions per agreement, current and from hoaddata 0.3.

- `legacy/jct_hybrid_jns.csv.gz`: JCT lists used by hoaddata 0.3, kept
  so that journals and agreements no longer listed in the JCT stay in.

- `openalex_sources.csv`: OpenAlex journals with ISSNs and open access
  status, written by
  [`jn_fetch_openalex_sources()`](https://njahn82.github.io/jn_analytics/reference/jn_fetch_openalex_sources.md).
  ISSN-Ls, titles, OpenAlex IDs and `oa_model` come from here; ISSNs
  that OpenAlex does not know fall back to the legacy file.

- `legacy/journal_titles.csv`: fallback journal titles.

- `manual/*.csv`: curated lookups (publisher names, OA models,
  publishers that flipped their journals to open access, exclusions,
  portfolios).
