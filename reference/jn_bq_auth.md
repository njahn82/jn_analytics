# Authenticate with BigQuery

Uses the service-account key in `GOOGLE_APPLICATION_CREDENTIALS` when
that variable points to a file (as in GitHub Actions), and otherwise the
cached user login of `bigrquery`/`gargle`.

## Usage

``` r
jn_bq_auth()
```

## Value

`TRUE`, invisibly.
