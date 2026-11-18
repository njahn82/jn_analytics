test_that("the targets pipeline is valid and builds tables in order", {
  skip_if_not_installed("targets")
  pipeline <- test_path("..", "..", "_targets.R")
  skip_if_not(file.exists(pipeline), "_targets.R not available")
  withr::local_dir(dirname(pipeline))
  expect_no_error(targets::tar_validate())
  edges <- targets::tar_network(targets_only = TRUE)$edges
  upstream <- function(x) edges$from[edges$to == x]
  expect_contains(upstream("bq_articles"), c("journal_ids", "sql_articles", "snapshots"))
  expect_disjoint(upstream("bq_articles"), c("upload_portfolios", "upload_agreements"))
  expect_contains(upstream("bq_agreement_journal_year"), "bq_article_agreements")
  expect_setequal(
    upstream("hf_release"),
    c("export_tables", "export_articles", "export_article_first_authors", "export_article_agreements")
  )
  expect_equal(upstream("export_articles"), "bq_articles")
})
