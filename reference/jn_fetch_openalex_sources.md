# Fetch OpenAlex journal metadata for the JCT journals

Downloads ISSN, ISSN-L, title and open access status of all OpenAlex
sources with an ISSN-L, keeps the sources sharing an ISSN with a current
or legacy JCT journal list, and writes them to `openalex_sources.csv` in
`raw_dir`.
[`jn_update_reference()`](https://njahn82.github.io/jn_analytics/reference/jn_update_reference.md)
then uses this file to assign ISSN-Ls and to classify journals as hybrid
or fully open access.

## Usage

``` r
jn_fetch_openalex_sources(raw_dir = "data-raw", config = jn_bq_config())
```

## Arguments

- raw_dir:

  Directory with `jct_jn_all.csv.gz`; the result is written here.

- config:

  See
  [`jn_bq_config()`](https://njahn82.github.io/jn_analytics/reference/jn_bq_config.md).

## Value

The path to the written file, invisibly.

## Details

The query reads only the small `sources` table (about 20 MB).
