test_that("jn_source() reads tables split into one file per year", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  src <- local_jn_source()
  dir.create(file.path(src$path, "article_first_authors"))
  for (year in 2024:2025) {
    x <- tibble::tibble(
      doi = paste0("10.1/", year), pub_year = year,
      ror = NA_character_, country_code = "DE", country_source = "affiliation"
    )
    write_jn_parquet(
      x, "article_first_authors",
      file.path(src$path, "article_first_authors", paste0("article_first_authors_", year, ".parquet"))
    )
  }

  src <- jn_source(src$path)
  expect_contains(src$tables, c("journal_year", "article_first_authors"))
  out <- dplyr::collect(jn_tbl(src, "article_first_authors"))
  expect_setequal(out$pub_year, 2024:2025)
})
