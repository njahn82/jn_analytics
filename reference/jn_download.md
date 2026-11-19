# Download the jnanalytics data

Downloads a release of the jnanalytics tables from Hugging Face into a
folder, or updates the folder when a newer release exists, and returns
the folder as a source for the analysis functions. Nothing is downloaded
when the folder is up to date.

## Usage

``` r
jn_download(
  dir = "my_data",
  release = NULL,
  tables = "default",
  repo = jn_hf_repo()
)
```

## Arguments

- dir:

  Folder for the data, created if needed.

- release:

  `NULL` (default) for the latest release, or for the frozen release if
  the folder is frozen. A release tag such as `"2026-11-18"` downloads
  that release and freezes the folder: later calls do not update it.
  `"latest"` lifts the freeze.

- tables:

  `"default"` for all tables except the large article tables
  (`articles`, `article_first_authors`, `article_agreements`), `"all"`,
  or table names. Tables already in the folder are kept and updated too.

- repo:

  Hugging Face dataset repository.

## Value

A `jn_source` for `dir`, see
[`jn_source()`](https://njahn82.github.io/jn_analytics/reference/jn_source.md).

## Details

The folder holds the Parquet files and `jn_release.json`, which records
the release, its commit, the tables and whether the folder is frozen. A
download goes to a temporary folder first and replaces the old files
only when it is complete, so an interrupted download leaves the data
intact.

## Examples

``` r
if (FALSE) { # \dontrun{
src <- jn_download()
jn_oa(src, by = c("pub_year", "oa_model"))

# Freeze a project to one release
src <- jn_download(release = "2026-11-18")
} # }
```
