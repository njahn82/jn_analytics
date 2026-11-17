# analysis functions explain bad input

    Code
      jn_oa(src, by = "year")
    Condition
      Error in `jn_oa()`:
      ! Can't group by "year".
      i `by` can use "pub_year", "issn_l", "oa_model", "work_type", "country_code", "publisher", "portfolio_id", and "agreement_id".

---

    Code
      jn_oa(src, portfolio = "nope")
    Condition
      Error in `jn_oa()`:
      ! Unknown portfolio: "nope"
      i Available: "acm"

---

    Code
      jn_oa(src, agreement = "nope2025")
    Condition
      Error in `jn_oa()`:
      ! Unknown agreement: "nope2025"

---

    Code
      jn_tbl(src, "articles")
    Condition
      Error in `jn_tbl()`:
      ! Table "articles" is not in this source.
      i Article-level tables are only in BigQuery: use `jn_source("bigquery")`.

