test_that("normalize_issn() canonicalises and validates check digits", {
  expect_equal(
    normalize_issn(c("0021-843x", "0027 -4224", "03600300", "1557-7341")),
    c("0021-843X", "0027-4224", "0360-0300", "1557-7341")
  )
  expect_equal(
    normalize_issn(c("0360-0301", "2053-140", "yyyy-yyyy", "1031-461I", NA)),
    rep(NA_character_, 5)
  )
  expect_equal(normalize_issn(character()), character())
})

test_that("normalize_publisher() replaces & and applies the lookup", {
  lookup <- data.frame(name = "CSIRO", publisher = "CSIRO Publishing")
  expect_equal(
    normalize_publisher(c("Taylor & Francis", " CSIRO ", "Wiley"), lookup),
    c("Taylor and Francis", "CSIRO Publishing", "Wiley")
  )
})

test_that("slugify() gives stable ASCII slugs", {
  expect_equal(
    slugify(c("De Gruyter (SUB Göttingen)", "Taylor and Francis", "Café")),
    c("de-gruyter-sub-goettingen", "taylor-and-francis", "cafe")
  )
})

test_that("country_iso2() only codes national agreements", {
  expect_equal(
    country_iso2(c("Germany", "Chinese Taipei", "Albania, Armenia", NA)),
    c("DE", "TW", NA, NA)
  )
})

test_that("normalize_ror() gives full lowercase ROR URLs", {
  expect_equal(
    normalize_ror(c("ror.org/05gxyna29", "https://ror.org/02E2C7K09", " http://www.ror.org/02e2c7k09", "v", NA)),
    c("https://ror.org/05gxyna29", "https://ror.org/02e2c7k09", "https://ror.org/02e2c7k09", NA, NA)
  )
})
