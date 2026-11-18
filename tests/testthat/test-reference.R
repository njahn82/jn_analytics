test_that("build_issn_map() extends a known mapping via print/online pairs", {
  known <- tibble::tibble(issn = "0360-0300", issn_l = "0360-0300")
  jct <- tibble::tibble(issn_print = "0360-0300", issn_online = "1557-7341")
  map <- build_issn_map(known, jct)
  expect_equal(map$issn, c("0360-0300", "1557-7341"))
  expect_equal(map$issn_l, c("0360-0300", "0360-0300"))
})

test_that("build_issn_map() keeps the first mapping of an ISSN", {
  known <- tibble::tibble(
    issn = c("1557-7341", "1557-7341"),
    issn_l = c("0360-0300", "1557-7341")
  )
  jct <- tibble::tibble(issn_print = NA_character_, issn_online = NA_character_)
  map <- build_issn_map(known, jct)
  expect_equal(map$issn_l[map$issn == "1557-7341"], "0360-0300")
})

test_that("build_agreement_journals() keeps legacy links and drops exclusions", {
  issn_map <- tibble::tibble(
    issn = c("0360-0300", "1557-7341", "2153-2184"),
    issn_l = c("0360-0300", "0360-0300", "2153-2184")
  )
  jct <- tibble::tibble(
    esac_id = c("acm2025x", "acm2025x", "bad2025x"),
    journal_name = c("Surveys", "Unknown", "Surveys"),
    issn_print = c(NA, "9999-9999", "0360-0300"),
    issn_online = c("1557-7341", NA, NA),
    time_last_seen = as.POSIXct("2026-11-09", tz = "UTC")
  )
  legacy <- tibble::tibble(esac_id = "acm2021x", issn_l = "2153-2184")
  exclusions <- tibble::tibble(type = "agreement_id", value = "bad2025x")

  aj <- build_agreement_journals(jct, legacy, issn_map, exclusions)

  expect_equal(aj$table$agreement_id, c("acm2021x", "acm2025x"))
  expect_equal(aj$table$issn_l, c("2153-2184", "0360-0300"))
  expect_equal(aj$table$last_seen, as.Date(c(NA, "2026-11-09")))
  expect_equal(aj$unmatched$journal_name, "Unknown")
})

test_that("build_portfolios() lists the agreements of each publisher page", {
  agreements <- tibble::tibble(
    agreement_id = c("tf2021x", "tf2024y", "wiley2019deal"),
    publisher = c("Taylor and Francis", "Taylor and Francis", "Wiley")
  )
  links <- tibble::tibble(
    agreement_id = c("tf2021x", "tf2024y", "wiley2019deal"),
    issn_l = c("0360-0300", "0360-0300", "2153-2184")
  )
  config <- tibble::tibble(portfolio_label = "Taylor & Francis")

  out <- build_portfolios(config, agreements, links, publisher_names = NULL)
  expect_equal(out$portfolio_id, c("taylor-and-francis", "taylor-and-francis"))
  expect_equal(out$agreement_id, c("tf2021x", "tf2024y"))

  empty <- tibble::tibble(portfolio_label = "Elsevier")
  expect_snapshot(build_portfolios(empty, agreements, links, NULL), error = TRUE)
})

test_that("build_journals() classifies OA models with curated values first", {
  links <- tibble::tibble(
    agreement_id = "a1",
    issn_l = c("0360-0300", "2153-2184", "1557-7341", "0021-843X")
  )
  agreements <- tibble::tibble(agreement_id = "a1", publisher = "ACM")
  openalex <- tibble::tibble(
    openalex_source_id = c("https://openalex.org/S1", "https://openalex.org/S2", "https://openalex.org/S3"),
    issn_l = c("0360-0300", "2153-2184", "1557-7341"),
    issn = c("0360-0300", "2153-2184", "1557-7341"),
    title = c("Surveys", "Inroads", "Open"),
    host_organization = NA_character_, source_type = "journal",
    is_oa = c(FALSE, TRUE, FALSE), is_in_doaj = c(FALSE, FALSE, FALSE),
    oa_flip_year = c(NA, 2024L, NA), works_count = 10L
  )
  oa_models <- tibble::tibble(issn_l = "1557-7341", oa_model = "full_oa")
  jct <- tibble::tibble(journal_name = character(), issn_print = character(), issn_online = character())
  map <- tibble::tibble(issn = character(), issn_l = character())
  titles <- tibble::tibble(issn_l = character(), title = character())

  out <- build_journals(links, agreements, jct, map, titles, oa_models, openalex)

  expect_equal(out$issn_l, c("0021-843X", "0360-0300", "1557-7341", "2153-2184"))
  expect_equal(out$oa_model, c(NA, "hybrid", "full_oa", "full_oa"))
  expect_equal(out$oa_flip_year, c(NA, NA, NA, 2024L))
  expect_equal(out$title, c(NA, "Surveys", "Open", "Inroads"))

  # a publisher flip turns hybrid and unclassified journals fully OA; journals
  # already fully OA keep their flip year
  flips <- tibble::tibble(publisher = "ACM", full_oa_from = 2026L)
  out <- build_journals(links, agreements, jct, map, titles, oa_models, openalex, flips)
  expect_equal(out$oa_model, rep("full_oa", 4))
  expect_equal(out$oa_flip_year, c(2025L, 2025L, NA, 2024L))
})

test_that("build_agreements() infers the period of agreements missing from ESAC", {
  esac <- tibble::tibble(
    id = "acm2021x", publisher = "ACM", organization = "X", country = "Germany",
    start_date = as.POSIXct("2021-01-01", tz = "UTC"),
    end_date = as.POSIXct("2023-12-31", tz = "UTC")
  )
  last_seen <- tibble::tibble(
    agreement_id = c("acm2026y", "acm2026y"),
    last_seen = as.Date(c("2026-03-01", "2026-11-09"))
  )
  prefixes <- tibble::tibble(prefix = character(), publisher = character())
  out <- build_agreements(c("acm2021x", "acm2026y"), esac, prefixes, NULL, last_seen)

  expect_equal(out$is_period_inferred, c(FALSE, TRUE))
  expect_equal(out$start_date, as.Date(c("2021-01-01", "2026-01-01")))
  expect_equal(out$end_date, as.Date(c("2023-12-31", "2026-12-31")))
})

test_that("build_agreement_institutions() merges sources and drops invalid RORs", {
  jct <- tibble::tibble(
    esac_id = c("a1", "a1", "a1"),
    inst_name = c("TU Delft", "TU Delft", "No ROR"),
    ror_id = c("https://ror.org/02e2c7k09", "ror.org/02E2C7K09", NA),
    time_last_seen = as.POSIXct(c("2024-01-01", "2025-01-01", "2025-01-01"), tz = "UTC")
  )
  legacy <- tibble::tibble(
    esac_id = c("a2", "gone"), inst_name = "Old", ror_id = "https://ror.org/05gxyna29"
  )
  out <- build_agreement_institutions(jct, legacy, c("a1", "a2"))

  expect_equal(out$table$agreement_id, c("a1", "a2"))
  expect_equal(out$table$ror, c("https://ror.org/02e2c7k09", "https://ror.org/05gxyna29"))
  expect_equal(out$table$last_seen, as.Date(c("2025-01-01", NA)))
  expect_equal(out$no_ror$inst_name, "No ROR")
})

test_that("build_agreement_institutions() adds and removes curated institutions", {
  jct <- tibble::tibble(
    esac_id = "a1", inst_name = c("TU Delft", "Not a partner"),
    ror_id = c("https://ror.org/02e2c7k09", "https://ror.org/05gxyna29"),
    time_last_seen = as.POSIXct("2025-01-01", tz = "UTC")
  )
  legacy <- tibble::tibble(esac_id = "gone", inst_name = "Old", ror_id = "https://ror.org/05gxyna29")
  corrections <- tibble::tibble(
    agreement_id = "a1", action = c("add", "remove"),
    ror = c("ror.org/04qr3zq92", "https://ror.org/05gxyna29"),
    inst_name = c("UESTC", "Not a partner"), reason = "partner list"
  )
  out <- build_agreement_institutions(jct, legacy, "a1", corrections)

  expect_equal(out$table$ror, c("https://ror.org/02e2c7k09", "https://ror.org/04qr3zq92"))
  expect_equal(out$table$inst_name, c("TU Delft", "UESTC"))
  expect_equal(out$table$last_seen, as.Date(c("2025-01-01", NA)))
})

test_that("institution corrections that no longer apply stop the build", {
  table <- tibble::tibble(
    agreement_id = "a1", ror = "https://ror.org/02e2c7k09",
    inst_name = "TU Delft", last_seen = as.Date("2025-01-01")
  )
  corrections <- tibble::tibble(
    agreement_id = c("a1", "a1", "gone", "a1"),
    action = c("add", "remove", "add", "drop"),
    ror = c("https://ror.org/02e2c7k09", "https://ror.org/05gxyna29", "https://ror.org/04qr3zq92", "https://ror.org/00g2ypp58"),
    inst_name = c("TU Delft", "Not listed", "UESTC", "Other"), reason = "test"
  )
  expect_snapshot(apply_institution_corrections(table, corrections, "a1"), error = TRUE)
})

test_that("the curated institution corrections fit the bundled data", {
  path <- test_path("..", "..", "data-raw", "manual", "institution_corrections.csv")
  skip_if_not(file.exists(path), "data-raw not available")
  corrections <- readr::read_csv(path, col_types = readr::cols(.default = "c"))
  key <- paste(agreement_institutions$agreement_id, agreement_institutions$ror)
  wanted <- paste(corrections$agreement_id, corrections$ror)
  expect_in(wanted[corrections$action == "add"], key)
  expect_disjoint(wanted[corrections$action == "remove"], key)
})

test_that("jn_save_reference() writes one .rda per reference table", {
  dir <- withr::local_tempdir()
  ref <- list(
    journals = journals, journal_issns = journal_issns, agreements = agreements,
    agreement_journals = agreement_journals,
    agreement_institutions = agreement_institutions, portfolios = portfolios,
    diagnostics = list()
  )
  files <- jn_save_reference(ref, dir)
  expect_equal(basename(files), paste0(names(ref)[1:6], ".rda"))
  env <- new.env()
  load(files[1], envir = env)
  expect_equal(env$journals, journals)
})
