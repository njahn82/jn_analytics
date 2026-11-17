test_that("coerce_to_schema() casts types and orders columns", {
  x <- data.frame(
    last_seen = "2026-11-09",
    issn_l = "0360-0300",
    agreement_id = "acm2025x",
    extra = 1
  )
  out <- coerce_to_schema(x, "agreement_journals")
  expect_named(out, c("agreement_id", "issn_l", "last_seen"))
  expect_s3_class(out$last_seen, "Date")
})

test_that("write_jn_parquet() stores column descriptions as metadata", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  file <- withr::local_tempfile(fileext = ".parquet")
  x <- tibble::tibble(issn = "1557-7341", issn_l = "0360-0300")

  write_jn_parquet(x, "journal_issns", file)

  back <- arrow::read_parquet(file, as_data_frame = FALSE)
  expect_equal(as.data.frame(back), as.data.frame(x))
  expect_equal(back$metadata$jn_table, "journal_issns")
  columns <- jsonlite::fromJSON(back$metadata$jn_columns)
  expect_equal(columns$issn, "Any ISSN of the journal")
})
