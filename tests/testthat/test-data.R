test_that("bundled reference tables match the schema and each other", {
  ref <- list(
    journals = journals,
    journal_issns = journal_issns,
    agreements = agreements,
    agreement_journals = agreement_journals,
    agreement_institutions = agreement_institutions,
    portfolios = portfolios
  )
  expect_invisible(validate_reference(ref))
  expect_in(journals$issn_l, agreement_journals$issn_l)
  expect_in(agreements$agreement_id, agreement_journals$agreement_id)
  expect_in(journals$publisher, agreements$publisher)
})

test_that("curated lists are applied", {
  # data-raw/ is not part of the built package, so this only runs from source
  dir <- test_path("..", "..", "data-raw", "manual")
  skip_if_not(dir.exists(dir), "data-raw/ not available")

  exclusions <- read.csv(file.path(dir, "exclusions.csv"))
  expect_disjoint(exclusions$value, agreements$agreement_id)

  oa_model <- read.csv(file.path(dir, "oa_model.csv"))
  matched <- merge(oa_model, journals, by = "issn_l", suffixes = c("", ".data"))
  expect_equal(matched$oa_model.data, matched$oa_model)
})
