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

test_that("jn_publish_tables() lists every table but release", {
  expect_setequal(c(jn_publish_tables(), "release"), jn_tables())
})

test_that("jn_publish() rejects unknown tables", {
  expect_snapshot(jn_publish(withr::local_tempdir(), tables = "nope"), error = TRUE)
})

test_that("partition_years() keeps year partitions only", {
  expect_equal(partition_years(c("2017", "__NULL__", NA, "2016", "__UNPARTITIONED__")), 2016:2017)
  expect_equal(partition_years(NA_character_), integer())
})

test_that("year_queries() read one partition each", {
  config <- jn_bq_config(project = "p", dataset = "d")
  expect_equal(
    year_queries("articles", 2016:2017, config),
    c(
      "SELECT * FROM `p.d.articles` WHERE pub_year = 2016",
      "SELECT * FROM `p.d.articles` WHERE pub_year = 2017"
    )
  )
})

test_that("write_jn_parquet() passes options such as the row group size", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  file <- withr::local_tempfile(fileext = ".parquet")
  x <- tibble::tibble(issn = rep("1557-7341", 10), issn_l = "0360-0300")
  write_jn_parquet(x, "journal_issns", file, chunk_size = 4)
  expect_equal(arrow::ParquetFileReader$create(file)$num_row_groups, 3)
})
