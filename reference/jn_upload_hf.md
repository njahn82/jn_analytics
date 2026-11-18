# Upload a release to Hugging Face

Writes the dataset card (`README.md`) into `path`, uploads the folder
written by
[`jn_publish()`](https://njahn82.github.io/jn_analytics/reference/jn_publish.md)
to the Hugging Face dataset repository in one commit and tags that
commit with the build date of the release (`release$snapshot_date`, e.g.
`2026-11-17`). Parquet files in the repository that are not part of the
upload are deleted in the same commit; earlier releases stay available
under their tags.

## Usage

``` r
jn_upload_hf(path = "parquet", repo = jn_hf_repo(), tag = NULL)
```

## Arguments

- path:

  Directory written by
  [`jn_publish()`](https://njahn82.github.io/jn_analytics/reference/jn_publish.md),
  with `release.parquet`.

- repo:

  Hugging Face dataset repository.

- tag:

  Tag for the release. Defaults to its build date.

## Value

The tag, invisibly.

## Details

Needs the Hugging Face CLI (`hf`) and a token with write access to
`repo`, from `hf auth login` or the `HF_TOKEN` environment variable. If
the tag exists already (a second build on the same day), it is moved to
the new commit.
