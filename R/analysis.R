#' Open access in the journal market
#'
#' Counts works and open access works, and computes OA shares, for all
#' journals or a dashboard portfolio, hybrid or fully open access, globally or
#' for first-author countries.
#' The same code runs on the Parquet export and on BigQuery (see
#' [jn_source()]).
#'
#' Statistics per agreement are journal-level: all works in the journals an
#' agreement covers, whoever the authors are. A journal covered by several
#' agreements counts in each of them, so results by `agreement_id` must not be
#' summed over agreements. Works matched to an agreement through their
#' authors' institutions are in the `agreement_journal_year` table.
#'
#' Journal and country totals follow the counting rules of the data model:
#' without `country`, counts come from `journal_year` and every work counts
#' once. With `country`, or `"country_code"` in `by`, they come from the
#' country tables, where a work with first authors in several countries counts
#' once per country (full counting).
#'
#' @param src A [jn_source()]. Defaults to the Parquet files in `parquet/`.
#' @param by Columns to group by: any of `pub_year`, `issn_l`, `publisher`,
#'   `portfolio_id`, `agreement_id`, `oa_model`, `work_type`, `country_code`.
#' @param portfolio Portfolio IDs (see [portfolios]) to restrict to, or `NULL`
#'   for all journals.
#' @param agreement ESAC IDs (see [agreements]) to restrict to the journals of
#'   these agreements, or `NULL`.
#' @param agreement_period With `agreement` or `"agreement_id"` in `by`: if
#'   `TRUE` (default), count a journal's works only in the years in which the
#'   agreement ran (by publication year; agreements without a period are
#'   left out). If `FALSE`, count all years.
#' @param country ISO-2 codes of first-author countries, or `NULL` for all
#'   works.
#' @param work_types OpenAlex work types to include; `NULL` for all. The
#'   default counts research articles.
#' @param oa_model `NULL` (default) for all journals, or `"hybrid"` and/or
#'   `"full_oa"` to restrict to these journals. Use `by = "oa_model"` to
#'   compare them. The OA model is taken per year: a journal that became fully
#'   OA in its OpenAlex `oa_flip_year` counts as hybrid up to and including
#'   that year, which is usually a transition year.
#'
#' @return A tibble with the `by` columns, `articles`, `articles_oa`,
#'   `articles_oa_openalex`, and the shares `share_oa` and
#'   `share_oa_openalex`. `articles_oa` counts every work in a fully OA
#'   journal-year and, in hybrid journal-years, works with a CC licence in
#'   Crossref; fully OA journals therefore have `share_oa` 1. How many works
#'   carry a CC licence in Crossref is in [jn_metadata()] (`share_cc_license`)
#'   and [jn_licenses()].
#' @export
#' @examples
#' \dontrun{
#' # Global trend of research articles, hybrid vs fully OA journals
#' jn_oa(by = c("pub_year", "oa_model"))
#'
#' # Hybrid journals in the Wiley portfolio, German first authors, by licence
#' jn_licenses(portfolio = "wiley", country = "DE", oa_model = "hybrid")
#'
#' # Top countries in 2025
#' jn_oa(by = "country_code") |> dplyr::filter(articles > 10000)
#'
#' # OA in the journals of each Wiley agreement, during the agreement period
#' jn_oa(portfolio = "wiley", by = c("agreement_id", "pub_year"))
#' }
jn_oa <- function(src = jn_source(), by = "pub_year", portfolio = NULL,
                  agreement = NULL, agreement_period = TRUE, country = NULL,
                  work_types = c("article", "review"), oa_model = NULL) {
  out <- jn_summarise(
    src, "journal_year",
    counts = c("articles", "articles_oa", "articles_oa_openalex"),
    by = by, portfolio = portfolio, agreement = agreement,
    agreement_period = agreement_period, country = country,
    work_types = work_types, oa_model = oa_model
  )
  dplyr::mutate(
    out,
    share_oa = .data$articles_oa / .data$articles,
    share_oa_openalex = .data$articles_oa_openalex / .data$articles
  )
}

#' @rdname jn_oa
#' @details `jn_licenses()` splits works by CC licence in Crossref (`NA` =
#'   no CC licence, which in a fully OA journal is a metadata gap, not closed
#'   access); `share` is relative to all works in the `by` group.
#' @export
jn_licenses <- function(src = jn_source(), by = "pub_year", portfolio = NULL,
                        agreement = NULL, agreement_period = TRUE, country = NULL,
                        work_types = c("article", "review"), oa_model = NULL) {
  out <- jn_summarise(
    src, "journal_year_license",
    counts = "articles",
    by = c(by, "cc_license"), portfolio = portfolio, agreement = agreement,
    agreement_period = agreement_period, country = country,
    work_types = work_types, oa_model = oa_model
  )
  out |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
    dplyr::mutate(share = .data$articles / sum(.data$articles)) |>
    dplyr::ungroup()
}

#' @rdname jn_oa
#' @details `jn_metadata()` reports how many works carry each kind of
#'   Crossref metadata, including a CC licence (`share_cc_license`). Shares
#'   are relative to `articles_in_crossref`.
#' @export
jn_metadata <- function(src = jn_source(), by = "pub_year", portfolio = NULL,
                        agreement = NULL, agreement_period = TRUE, country = NULL,
                        work_types = c("article", "review"), oa_model = NULL) {
  indicators <- c(
    "cc_license", "tdm_link", "orcid", "affiliation", "affiliation_ror", "funder",
    "funder_id", "abstract", "references"
  )
  counts <- c("articles", "articles_in_crossref", paste0("articles_with_", indicators))
  out <- jn_summarise(
    src, "journal_year",
    counts = counts, by = by, portfolio = portfolio, agreement = agreement,
    agreement_period = agreement_period, country = country,
    work_types = work_types, oa_model = oa_model
  )
  for (i in indicators) {
    out[[paste0("share_", i)]] <- out[[paste0("articles_with_", i)]] / out$articles_in_crossref
  }
  out
}

# Filter, group and sum a journal-level count table in the source, then add
# journal attributes (publisher, portfolio, agreement) locally. `oa_model` is
# a column of the count tables, so it reflects the OA model in each year.
jn_summarise <- function(src, base, counts, by, portfolio, agreement,
                         agreement_period, country, work_types, oa_model,
                         call = rlang::caller_env()) {
  journal_cols <- c("publisher", "portfolio_id", "agreement_id")
  allowed <- c(
    "pub_year", "issn_l", "oa_model", "work_type", "country_code", "cc_license",
    journal_cols
  )
  bad <- setdiff(by, allowed)
  if (length(bad) > 0) {
    cli::cli_abort(c(
      "Can't group by {.val {bad}}.",
      "i" = "{.arg by} can use {.val {setdiff(allowed, 'cc_license')}}."
    ), call = call)
  }
  if (!is.null(oa_model) && !all(oa_model %in% c("hybrid", "full_oa"))) {
    cli::cli_abort(
      "{.arg oa_model} must be {.val hybrid}, {.val full_oa} or {.code NULL}.",
      call = call
    )
  }

  country_level <- !is.null(country) || "country_code" %in% by
  table <- if (country_level) sub("^journal_year", "journal_year_country", base) else base
  journals <- journal_selection(src, portfolio, agreement, by, call = call)
  period <- isTRUE(agreement_period) && journals$agreement_level

  q <- jn_tbl(src, table)
  if (!is.null(journals$ids)) {
    ids <- journals$ids
    q <- dplyr::filter(q, .data$issn_l %in% !!ids)
  }
  if (!is.null(oa_model)) {
    q <- dplyr::filter(q, .data$oa_model %in% !!oa_model)
  }
  if (!is.null(work_types)) {
    q <- dplyr::filter(q, .data$work_type %in% !!work_types)
  }
  if (!is.null(country)) {
    q <- dplyr::filter(q, .data$country_code %in% !!toupper(country))
  }

  by_journal <- intersect(by, journal_cols)
  local_join <- length(by_journal) > 0 || period
  source_by <- unique(c(
    setdiff(by, journal_cols),
    if (local_join) "issn_l",
    if (period) "pub_year"
  ))
  sums <- rlang::set_names(
    lapply(counts, function(col) rlang::expr(sum(!!rlang::sym(col), na.rm = TRUE))),
    counts
  )
  out <- q |>
    dplyr::group_by(!!!rlang::syms(source_by)) |>
    dplyr::summarise(!!!sums, .groups = "drop") |>
    dplyr::collect()

  if (local_join) {
    lookup_cols <- unique(c(
      "issn_l", by_journal,
      if (period) c("agreement_id", "start_year", "end_year")
    ))
    lookup <- dplyr::distinct(journals$lookup[lookup_cols])
    out <- dplyr::inner_join(out, lookup, by = "issn_l", relationship = "many-to-many")
    if (period) {
      out <- out |>
        dplyr::filter(.data$pub_year >= .data$start_year, .data$pub_year <= .data$end_year) |>
        # a journal-year in several selected agreements counts once, unless
        # results are split by agreement
        dplyr::distinct(dplyr::across(dplyr::all_of(c(source_by, by_journal))), .keep_all = TRUE)
    }
    out <- out |>
      dplyr::group_by(!!!rlang::syms(by)) |>
      dplyr::summarise(
        dplyr::across(dplyr::all_of(counts), \(x) sum(x, na.rm = TRUE)),
        .groups = "drop"
      )
  }
  out |>
    dplyr::mutate(dplyr::across(dplyr::all_of(counts), as.numeric)) |>
    dplyr::arrange(!!!rlang::syms(by))
}

# Journals of the selected portfolios and agreements. A portfolio is a set of
# agreements; journals come from `agreement_journals`. `ids` is NULL when
# nothing is selected; `lookup` has one row per journal (and agreement, with
# its portfolio and the years of its period).
journal_selection <- function(src, portfolio, agreement, by, call = rlang::caller_env()) {
  journals <- dplyr::collect(jn_tbl(src, "journals"))[c("issn_l", "publisher")]
  agreement_level <- !is.null(agreement) || "agreement_id" %in% by
  if (is.null(portfolio) && !agreement_level && !"portfolio_id" %in% by) {
    return(list(ids = NULL, lookup = journals, agreement_level = FALSE))
  }

  ports <- dplyr::collect(jn_tbl(src, "portfolios"))
  agreements <- dplyr::collect(jn_tbl(src, "agreements"))
  if (!is.null(portfolio)) {
    bad <- setdiff(portfolio, ports$portfolio_id)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Unknown portfolio{?s}: {.val {bad}}",
        "i" = "Available: {.val {unique(ports$portfolio_id)}}"
      ), call = call)
    }
  }
  if (!is.null(agreement)) {
    bad <- setdiff(agreement, agreements$agreement_id)
    if (length(bad) > 0) {
      cli::cli_abort("Unknown agreement{?s}: {.val {bad}}", call = call)
    }
  }

  # Agreements to look at: those of the selected portfolios, the selected
  # ESAC IDs, all portfolio agreements, or all agreements
  ids <- if (!is.null(portfolio)) {
    ports$agreement_id[ports$portfolio_id %in% portfolio]
  } else if (agreement_level) {
    agreements$agreement_id
  } else {
    ports$agreement_id
  }
  if (!is.null(agreement)) ids <- intersect(ids, agreement)

  map <- jn_tbl(src, "agreement_journals") |>
    dplyr::filter(.data$agreement_id %in% !!ids) |>
    dplyr::distinct(.data$agreement_id, .data$issn_l) |>
    dplyr::collect() |>
    dplyr::left_join(ports[c("agreement_id", "portfolio_id")], by = "agreement_id") |>
    dplyr::left_join(
      dplyr::transmute(
        agreements, .data$agreement_id,
        start_year = as.integer(format(.data$start_date, "%Y")),
        end_year = as.integer(format(.data$end_date, "%Y"))
      ),
      by = "agreement_id"
    )

  selected <- !is.null(portfolio) || !is.null(agreement)
  lookup <- if (selected) {
    dplyr::inner_join(journals, map, by = "issn_l", relationship = "one-to-many")
  } else {
    dplyr::left_join(journals, map, by = "issn_l", relationship = "one-to-many")
  }
  list(
    ids = if (selected) unique(map$issn_l) else NULL,
    lookup = lookup,
    agreement_level = agreement_level
  )
}
