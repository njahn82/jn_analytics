# an incomplete download leaves the folder unchanged

    Code
      jn_download(dir)
    Condition
      Error in `jn_download()`:
      ! Download of 'journal_year.parquet' is incomplete; the folder was not changed.

# jn_download() works offline with data and stops without

    Code
      jn_download(withr::local_tempdir())
    Condition
      Error in `jn_download()`:
      ! Hugging Face not reachable, and '<dir>' has no jnanalytics data yet.

# jn_download() explains unknown releases and tables

    Code
      jn_download(withr::local_tempdir(), release = "2020-01-01")
    Condition
      Error in `jn_download()`:
      ! Release "2020-01-01" not found.
      i Available: "2026-11-18" and "2026-08-01"

---

    Code
      jn_download(withr::local_tempdir(), tables = "nope")
    Condition
      Error in `jn_download()`:
      ! Unknown table: "nope".
      i Use "default", "all" or names from `jn_publish_tables()`.

