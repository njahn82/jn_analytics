test_that("the schema covers all tables of the data model", {
  expect_setequal(jn_tables(), c(
    "journals", "journal_issns", "agreements", "agreement_journals",
    "agreement_institutions", "article_agreements", "agreement_journal_year",
    "portfolios", "articles", "article_first_authors", "journal_year", "journal_year_country",
    "journal_year_country_license", "journal_year_license", "release"
  ))
  schema <- jn_schema()
  expect_in(schema$type, c("string", "integer", "boolean", "date"))
  expect_equal(anyDuplicated(schema[c("table", "column")]), 0)
  expect_all_true(nzchar(schema$description))
  expect_all_true(as.vector(tapply(schema$key, schema$table, any)))
})

test_that("column names follow the naming conventions", {
  schema <- jn_schema()
  expect_all_true(grepl("^[a-z][a-z0-9_]*$", schema$column))
  booleans <- schema$column[schema$type == "boolean"]
  expect_all_true(grepl("^(is|has)_", booleans))
  counts <- setdiff(
    schema$column[schema$type == "integer"],
    c("pub_year", "pub_year_crossref", "pub_year_min", "pub_year_max", "oa_flip_year")
  )
  # Aggregates count articles; per-article counts start with `n_`
  expect_all_true(grepl("^(articles|n_)", counts))
})

test_that("jn_validate() accepts a conforming table", {
  ok <- tibble::tibble(issn = c("0360-0300", "1557-7341"), issn_l = "0360-0300")
  expect_invisible(jn_validate(ok, "journal_issns"))
})

test_that("jn_validate() reports column, type, format and key problems", {
  bad <- tibble::tibble(
    issn = c("0021-843x", "0021-843x", NA),
    issn_l = 1:3
  )
  expect_snapshot(jn_validate(bad, "journal_issns"), error = TRUE)
  expect_snapshot(jn_validate(bad["issn"], "journal_issns"), error = TRUE)
})

test_that("jn_validate() checks controlled vocabularies", {
  journals <- tibble::tibble(
    issn_l = "0360-0300", title = "ACM Computing Surveys",
    publisher = "ACM", oa_model = "diamond", oa_flip_year = NA_integer_,
    openalex_source_id = "https://openalex.org/S123"
  )
  expect_snapshot(jn_validate(journals, "journals"), error = TRUE)
})

test_that("jn_schema() rejects unknown tables", {
  expect_snapshot(jn_schema("jn_ind"), error = TRUE)
})

test_that("jn_validate() knows every match type", {
  x <- tibble::tibble(
    doi = paste0("10.1/", 1:5), pub_year = 2025L, agreement_id = "a1",
    author_role = "first", ror_author = paste0("https://ror.org/0", 1:5),
    ror_agreement = "https://ror.org/09",
    match_type = c("direct", "child", "parent", "parent_single", "related")
  )
  expect_no_error(jn_validate(x, "article_agreements"))
  x$match_type[1] <- "grandparent"
  expect_error(jn_validate(x, "article_agreements"), "non-canonical")
})
