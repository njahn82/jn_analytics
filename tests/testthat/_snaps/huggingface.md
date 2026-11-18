# jn_upload_hf() refuses an incomplete export

    Code
      jn_upload_hf(dir)
    Condition
      Error in `jn_upload_hf()`:
      ! '<dir>' lacks table "articles".
      i Export all tables with `jn_publish()` first.

---

    Code
      jn_upload_hf(dir)
    Condition
      Error in `jn_upload_hf()`:
      ! '<dir>/release.parquet' not found. Export with `jn_publish()` first.

