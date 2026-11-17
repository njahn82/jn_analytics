# Save the reference tables as package data

Writes each reference table to `dir` as an xz-compressed `.rda` file, as
`usethis::use_data()` would, but without needing an active project (for
example in GitHub Actions).

## Usage

``` r
jn_save_reference(ref, dir = "data")
```

## Arguments

- ref:

  The list returned by
  [`jn_update_reference()`](https://njahn82.github.io/jn_analytics/reference/jn_update_reference.md).

- dir:

  The package's `data/` directory.

## Value

The written file paths, invisibly.
