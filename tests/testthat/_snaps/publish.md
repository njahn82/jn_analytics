# jn_publish() rejects unknown tables

    Code
      jn_publish(withr::local_tempdir(), tables = "nope")
    Condition
      Error in `jn_publish()`:
      ! Unknown table to export: "nope"

