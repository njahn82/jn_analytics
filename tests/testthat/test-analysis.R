test_that("jn_oa() counts research articles in all journals by default", {
  skip_if_not_installed("arrow")
  src <- local_jn_source()
  out <- jn_oa(src)
  expect_equal(out$articles, 30)
  expect_equal(out$articles_oa, 24)
  expect_equal(out$share_oa, 0.8)
})

test_that("jn_oa() splits or restricts by OA model", {
  skip_if_not_installed("arrow")
  src <- local_jn_source()
  out <- jn_oa(src, by = "oa_model", work_types = NULL)
  expect_equal(out$oa_model, c("full_oa", "hybrid"))
  expect_equal(out$articles, c(20, 15))
  expect_equal(jn_oa(src, oa_model = "hybrid")$share_oa, 0.4)
  expect_equal(jn_oa(src, oa_model = "full_oa")$share_oa, 1)
})

test_that("jn_oa() finds portfolio journals through the portfolio's agreements", {
  skip_if_not_installed("arrow")
  src <- local_jn_source()
  out <- jn_oa(src, by = c("portfolio_id", "publisher"), portfolio = "acm")
  expect_equal(out$portfolio_id, "acm")
  expect_equal(out$articles, 10)

  # without a filter, journals outside any portfolio form their own group
  all <- jn_oa(src, by = "portfolio_id")
  expect_equal(all$portfolio_id, c("acm", NA))
  expect_equal(all$articles, c(10, 20))
})

test_that("jn_oa() gives journal-level statistics per agreement", {
  skip_if_not_installed("arrow")
  src <- local_jn_source()

  # 2025 lies in the period of acm2025x only
  out <- jn_oa(src, by = "agreement_id", work_types = NULL)
  expect_equal(out$agreement_id, "acm2025x")
  expect_equal(out$articles, 15)

  all_years <- jn_oa(src, by = "agreement_id", agreement_period = FALSE)
  expect_equal(all_years$agreement_id, c("acm2025x", "other2026"))
  expect_equal(all_years$articles, c(10, 20))

  expect_equal(jn_oa(src, agreement = "acm2025x")$articles, 10)
  expect_equal(nrow(jn_oa(src, agreement = "other2026")), 0)
  expect_equal(
    jn_oa(src, portfolio = "acm", by = c("portfolio_id", "agreement_id"))$agreement_id,
    "acm2025x"
  )
})

test_that("jn_oa() uses the country tables for countries", {
  skip_if_not_installed("arrow")
  src <- local_jn_source()
  expect_equal(jn_oa(src, country = "de")$articles, 6)
  by_country <- jn_oa(src, by = "country_code")
  expect_equal(by_country$country_code, c("DE", "US"))
  expect_equal(by_country$share_oa, c(0.5, 0.2))
})

test_that("jn_licenses() gives shares that sum to one per group", {
  skip_if_not_installed("arrow")
  src <- local_jn_source()
  out <- jn_licenses(src, oa_model = "hybrid")
  expect_equal(out$cc_license, c("CC BY", NA))
  expect_equal(out$share, c(0.4, 0.6))
  expect_equal(sum(jn_licenses(src, country = "US")$articles), 5)
})

test_that("jn_metadata() uses Crossref records as denominator", {
  skip_if_not_installed("arrow")
  src <- local_jn_source()
  out <- jn_metadata(src, oa_model = "hybrid")
  expect_equal(out$share_orcid, 0.4)
  expect_equal(out$share_abstract, 1)
  expect_equal(out$share_cc_license, 0.4)
})

test_that("analysis functions explain bad input", {
  skip_if_not_installed("arrow")
  src <- local_jn_source()
  expect_snapshot(jn_oa(src, by = "year"), error = TRUE)
  expect_snapshot(jn_oa(src, portfolio = "nope"), error = TRUE)
  expect_snapshot(jn_oa(src, agreement = "nope2025"), error = TRUE)
  expect_snapshot(jn_tbl(src, "articles"), error = TRUE)
})
