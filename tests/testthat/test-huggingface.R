test_that("export_files() maps files and year folders to tables", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  files <- export_files(local_export())
  expect_setequal(unique(files$table), c(jn_publish_tables(), "release"))
  expect_contains(files$file, c("journal_year.parquet", "articles/articles_2026.parquet"))
})

test_that("dataset_card() has one viewer config per table and the release", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  card <- dataset_card(local_export(), repo = "someone/jn_analytics")

  expect_equal(card[1], "---")
  expect_contains(card, c(
    "license: cc0-1.0",
    "- config_name: journal_year",
    "  data_files: \"journal_year.parquet\"",
    "- config_name: articles",
    "  data_files: \"articles/*.parquet\"",
    "## Release 2026-11-17"
  ))
  configs <- sub("- config_name: ", "", grep("^- config_name: ", card, value = TRUE))
  expect_setequal(configs, c(jn_publish_tables(), "release"))
  expect_match(card, "hf://datasets/someone/jn_analytics/journal_year.parquet", fixed = TRUE, all = FALSE)
  expect_match(card, "<summary><code>article_agreements</code></summary>", fixed = TRUE, all = FALSE)
})

test_that("jn_upload_hf() refuses an incomplete export", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  dir <- local_export()
  unlink(file.path(dir, "articles"), recursive = TRUE)
  hide_dir <- function(x) gsub(dir, "<dir>", x, fixed = TRUE)
  expect_snapshot(jn_upload_hf(dir), error = TRUE, transform = hide_dir)
  unlink(file.path(dir, "release.parquet"))
  expect_snapshot(jn_upload_hf(dir), error = TRUE, transform = hide_dir)
})
