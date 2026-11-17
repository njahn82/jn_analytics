# A tiny Parquet source with two journals (one hybrid, one fully OA), one
# portfolio with one agreement (2024-2026), a second agreement starting in
# 2026, and two first-author countries; all works are from 2025
local_jn_source <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  counts <- function(n, oa) {
    tibble::tibble(
      articles = n, articles_in_crossref = n, articles_oa = oa,
      articles_oa_openalex = oa, articles_with_cc_license = oa,
      articles_with_tdm_link = n,
      articles_with_orcid = oa, articles_with_affiliation = n,
      articles_with_affiliation_ror = 0L, articles_with_funder = oa,
      articles_with_funder_id = 0L, articles_with_abstract = n,
      articles_with_references = n
    )
  }
  tables <- list(
    journals = tibble::tibble(
      issn_l = c("0360-0300", "2153-2184"), title = c("H", "F"),
      publisher = c("ACM", "ACM"), oa_model = c("hybrid", "full_oa"),
      oa_flip_year = c(NA, 2020L),
      openalex_source_id = c("https://openalex.org/S1", "https://openalex.org/S2")
    ),
    portfolios = tibble::tibble(
      portfolio_id = "acm", portfolio_label = "ACM", agreement_id = "acm2025x"
    ),
    agreements = tibble::tibble(
      agreement_id = c("acm2025x", "other2026"),
      publisher = c("ACM", "Other"),
      start_date = as.Date(c("2024-01-01", "2026-01-01")),
      end_date = as.Date(c("2026-12-31", "2027-12-31"))
    ),
    agreement_journals = tibble::tibble(
      agreement_id = c("acm2025x", "other2026"),
      issn_l = c("0360-0300", "2153-2184"),
      last_seen = as.Date("2026-11-09")
    ),
    journal_year = dplyr::bind_cols(
      tibble::tibble(
        issn_l = c("0360-0300", "0360-0300", "2153-2184"),
        pub_year = c(2025L, 2025L, 2025L),
        oa_model = c("hybrid", "hybrid", "full_oa"),
        work_type = c("article", "editorial", "article")
      ),
      counts(c(10L, 5L, 20L), c(4L, 0L, 20L))
    ),
    journal_year_country = dplyr::bind_cols(
      tibble::tibble(
        issn_l = c("0360-0300", "0360-0300"), pub_year = 2025L,
        oa_model = "hybrid", work_type = "article", country_code = c("DE", "US")
      ),
      counts(c(6L, 5L), c(3L, 1L))
    ),
    journal_year_license = tibble::tibble(
      issn_l = c("0360-0300", "0360-0300", "0360-0300", "2153-2184"),
      pub_year = 2025L,
      oa_model = c("hybrid", "hybrid", "hybrid", "full_oa"),
      work_type = c("article", "article", "editorial", "article"),
      cc_license = c("CC BY", NA, NA, "CC BY"),
      articles = c(4L, 6L, 5L, 20L)
    ),
    journal_year_country_license = tibble::tibble(
      issn_l = "0360-0300", pub_year = 2025L, oa_model = "hybrid",
      work_type = "article", country_code = c("DE", "DE", "US", "US"),
      cc_license = c("CC BY", NA, "CC BY", NA),
      articles = c(3L, 3L, 1L, 4L)
    )
  )
  for (name in names(tables)) {
    write_jn_parquet(tables[[name]], name, file.path(dir, paste0(name, ".parquet")))
  }
  jn_source(dir)
}
