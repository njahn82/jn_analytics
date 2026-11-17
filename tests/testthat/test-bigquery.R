test_that("jn_sql() fills in datasets and years", {
  config <- jn_bq_config(project = "p", dataset = "d", openalex = "o.w", crossref = "c.s")
  sql <- jn_sql("articles", config, year_min = 2016L, year_max = 2026L)
  expect_match(sql, "`p.d.journals`", fixed = TRUE)
  expect_match(sql, "`o.w.works`", fixed = TRUE)
  expect_match(sql, "`c.s.snapshot`", fixed = TRUE)
  expect_match(sql, "BETWEEN 2016 AND 2026", fixed = TRUE)
  expect_no_match(sql, "{{", fixed = TRUE)
})

test_that("jn_sql() rejects unknown templates", {
  expect_snapshot(jn_sql("nope"), error = TRUE)
})

test_that("filter_jct_sources() keeps all ISSNs of matching sources", {
  sources <- tibble::tibble(
    openalex_source_id = c("S1", "S1", "S2"),
    issn_l = c("0360-0300", "0360-0300", "2153-2184"),
    issn = c("0360-0300", "1557-7341", "2153-2184")
  )
  out <- filter_jct_sources(sources, c("1557-7341", NA))
  expect_equal(out$issn, c("0360-0300", "1557-7341"))
})

test_that("articles.sql returns the columns of the schema, in order", {
  sql <- jn_sql("articles")
  final <- sub(".*\n\\)\n\nSELECT\n(.*?)\nFROM openalex\n.*", "\\1", sql)
  lines <- trimws(strsplit(final, ",\n")[[1]])
  columns <- ifelse(
    grepl(" AS ", lines),
    sub(".* AS ([a-z_]+)$", "\\1", lines),
    sub("^[a-z_]+\\.", "", lines)
  )
  expect_equal(columns, jn_schema("articles")$column)
})

test_that("jn_bq_fields() carries schema types and descriptions", {
  skip_if_not_installed("bigrquery")
  fields <- jn_bq_fields("agreements")
  expect_equal(vapply(fields, `[[`, "", "name"), jn_schema("agreements")$column)
  expect_equal(fields[[6]]$type, "DATE")
  expect_match(fields[[1]]$description, "ESAC")
})

test_that("every table in the build order has a complete template", {
  for (name in jn_build_order()) {
    expect_no_match(jn_sql(name), "{{", fixed = TRUE)
  }
})

test_that("aggregate templates return the schema columns, in order", {
  final_columns <- function(sql) {
    select <- tail(strsplit(sql, "\nSELECT\n", fixed = TRUE)[[1]], 1)
    select <- sub("\nFROM .*", "", select)
    lines <- trimws(strsplit(select, ",\n")[[1]])
    ifelse(grepl(" AS ", lines), sub(".* AS ([a-z_]+)$", "\\1", lines), sub("^[a-z_]+\\.", "", lines))
  }
  for (name in c("journal_year", "journal_year_country", "journal_year_license", "journal_year_country_license", "agreement_journal_year")) {
    expect_equal(final_columns(jn_sql(name)), jn_schema(name)$column, label = name)
  }
})

test_that("aggregates count the flip year and earlier years as hybrid", {
  for (name in c("journal_year", "journal_year_country", "journal_year_license",
                 "journal_year_country_license", "agreement_journal_year")) {
    expect_match(jn_sql(name), "a.pub_year <= j.oa_flip_year", fixed = TRUE, label = name)
  }
})
