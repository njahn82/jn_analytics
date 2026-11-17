#' Build the reference tables
#'
#' Rebuilds `journals`, `journal_issns`, `agreements`, `agreement_journals`,
#' `agreement_institutions` and `portfolios` from the raw Journal Checker Tool (JCT) and ESAC files in
#' `raw_dir`, validates them against [jn_schema()] and checks that every
#' `issn_l` and `agreement_id` resolves.
#'
#' Expected files in `raw_dir` (see `data-raw/README.md`):
#'
#' - `jct_jn_all.csv.gz`, `esac_df.csv`: current JCT journal lists and the ESAC
#'   registry.
#' - `jct_inst_all.csv`, `legacy/jct_institutions.csv`: participating
#'   institutions per agreement, current and from hoaddata 0.3.
#' - `legacy/jct_hybrid_jns.csv.gz`: JCT lists used by hoaddata 0.3, kept so
#'   that journals and agreements no longer listed in the JCT stay in.
#' - `openalex_sources.csv`: OpenAlex journals with ISSNs and open access
#'   status, written by [jn_fetch_openalex_sources()]. ISSN-Ls, titles,
#'   OpenAlex IDs and `oa_model` come from here; ISSNs that OpenAlex does not
#'   know fall back to the legacy file.
#' - `legacy/journal_titles.csv`: fallback journal titles.
#' - `manual/*.csv`: curated lookups (publisher names, OA models, exclusions,
#'   portfolios).
#'
#' @param raw_dir Directory with the raw files.
#' @param quiet If `FALSE`, report coverage diagnostics.
#'
#' @return A named list of six tibbles, plus a `diagnostics` element listing
#'   journal-list rows without ISSN-L and institutions without ROR ID.
#' @export
jn_update_reference <- function(raw_dir = "data-raw", quiet = FALSE) {
  inputs <- read_reference_inputs(raw_dir)

  issn_map <- build_issn_map(inputs$issn_l_map, inputs$jct_jn)
  aj <- build_agreement_journals(
    jct_jn = inputs$jct_jn,
    legacy_jct = inputs$legacy_jct,
    issn_map = issn_map,
    exclusions = inputs$exclusions
  )
  agreements <- build_agreements(
    agreement_ids = unique(aj$table$agreement_id),
    esac = inputs$esac,
    agreement_publishers = inputs$agreement_publishers,
    publisher_names = inputs$publisher_names,
    last_seen = aj$table
  )
  ai <- build_agreement_institutions(
    jct_inst = inputs$jct_inst,
    legacy_inst = inputs$legacy_inst,
    agreement_ids = agreements$agreement_id
  )
  journals <- build_journals(
    agreement_journals = aj$table,
    agreements = agreements,
    jct_jn = inputs$jct_jn,
    issn_map = issn_map,
    legacy_titles = inputs$legacy_titles,
    oa_models = inputs$oa_models,
    openalex = inputs$openalex
  )
  journal_issns <- build_journal_issns(issn_map, journals)
  portfolios <- build_portfolios(
    inputs$portfolios, agreements, aj$table, inputs$publisher_names
  )

  out <- list(
    journals = journals,
    journal_issns = journal_issns,
    agreements = agreements,
    agreement_journals = aj$table,
    agreement_institutions = ai$table,
    portfolios = portfolios
  )
  validate_reference(out)

  if (!quiet) {
    n_unmatched <- length(unique(aj$unmatched$journal_name))
    cli::cli_inform(c(
      "Reference tables built:",
      "*" = "{nrow(journals)} journals, {nrow(journal_issns)} ISSNs",
      "*" = "{sum(journals$oa_model == 'hybrid', na.rm = TRUE)} hybrid, {sum(journals$oa_model == 'full_oa', na.rm = TRUE)} fully OA, {sum(is.na(journals$oa_model))} not yet classified",
      "*" = "{nrow(agreements)} agreements ({sum(agreements$is_period_inferred)} with inferred period, {sum(is.na(agreements$start_date))} without), {nrow(aj$table)} agreement-journal links",
      "*" = "{nrow(ai$table)} agreement-institution links ({length(unique(ai$table$ror))} institutions)",
      "*" = "{length(unique(portfolios$portfolio_id))} portfolios",
      "!" = "{nrow(aj$unmatched)} JCT journal-list row{?s} without ISSN-L ({n_unmatched} distinct journal{?s})",
      "!" = "{nrow(ai$no_ror)} JCT institution row{?s} without a valid ROR ID, not matchable"
    ))
  }
  out$diagnostics <- list(unmatched_jct = aj$unmatched, institutions_without_ror = ai$no_ror)
  out
}

validate_reference <- function(ref) {
  for (tbl in names(ref)) {
    jn_validate(ref[[tbl]], tbl)
  }
  check_foreign_key(ref$journal_issns, ref$journals, "issn_l", "journal_issns", "journals")
  check_foreign_key(ref$agreement_journals, ref$journals, "issn_l", "agreement_journals", "journals")
  check_foreign_key(ref$agreement_journals, ref$agreements, "agreement_id", "agreement_journals", "agreements")
  check_foreign_key(ref$portfolios, ref$agreements, "agreement_id", "portfolios", "agreements")
  check_foreign_key(ref$agreement_institutions, ref$agreements, "agreement_id", "agreement_institutions", "agreements")
  # Every journal must be reachable by its own linking ISSN
  check_foreign_key(
    dplyr::rename(ref$journals["issn_l"], issn = "issn_l"),
    ref$journal_issns, "issn", "journals.issn_l as", "journal_issns"
  )
  invisible(ref)
}

read_reference_inputs <- function(raw_dir) {
  path <- function(...) file.path(raw_dir, ...)
  read <- function(file, ...) {
    if (!file.exists(path(file))) {
      cli::cli_abort("Raw file {.file {path(file)}} not found.")
    }
    readr::read_csv(
      path(file),
      show_col_types = FALSE, progress = FALSE, na = c("", "NA"), ...
    )
  }
  chr <- readr::cols(.default = readr::col_character())

  legacy_jct <- read("legacy/jct_hybrid_jns.csv.gz", col_types = chr)
  openalex <- if (file.exists(path("openalex_sources.csv"))) {
    read("openalex_sources.csv", col_types = readr::cols(
      is_oa = readr::col_logical(),
      is_in_doaj = readr::col_logical(),
      oa_flip_year = readr::col_integer(),
      works_count = readr::col_integer(),
      .default = readr::col_character()
    ))
  } else {
    cli::cli_warn(c(
      "{.file {path('openalex_sources.csv')}} not found.",
      "i" = "ISSN-Ls come from hoaddata 0.3 only, and journals are not classified.",
      "i" = "Run {.fn jn_fetch_openalex_sources} first."
    ))
    empty_openalex_sources()
  }
  # OpenAlex first; for an ISSN in several sources, the larger one wins.
  # hoaddata 0.3 fills in ISSNs OpenAlex does not know.
  issn_l_map <- dplyr::bind_rows(
    openalex |>
      dplyr::arrange(dplyr::desc(.data$works_count)) |>
      dplyr::distinct(.data$issn, .data$issn_l),
    dplyr::distinct(legacy_jct, .data$issn, .data$issn_l)
  )

  list(
    jct_jn = read("jct_jn_all.csv.gz", col_types = readr::cols(
      time_last_seen = readr::col_datetime(),
      .default = readr::col_character()
    )),
    esac = read("esac_df.csv", col_types = readr::cols(
      start_date = readr::col_datetime(),
      end_date = readr::col_datetime(),
      annual_publications = readr::col_double(),
      jct_jn = readr::col_logical(),
      jct_inst = readr::col_logical(),
      .default = readr::col_character()
    )),
    legacy_jct = legacy_jct,
    openalex = openalex,
    issn_l_map = issn_l_map,
    legacy_titles = read("legacy/journal_titles.csv", col_types = chr),
    exclusions = read("manual/exclusions.csv", col_types = chr),
    oa_models = read("manual/oa_model.csv", col_types = chr),
    publisher_names = read("manual/publisher_names.csv", col_types = chr),
    agreement_publishers = read("manual/agreement_publishers.csv", col_types = chr),
    portfolios = read("manual/portfolios.csv", col_types = chr),
    jct_inst = read("jct_inst_all.csv", col_types = readr::cols(
      time_last_seen = readr::col_datetime(),
      .default = readr::col_character()
    )),
    legacy_inst = read("legacy/jct_institutions.csv", col_types = chr)
  )
}

empty_openalex_sources <- function() {
  tibble::tibble(
    openalex_source_id = character(), issn_l = character(), issn = character(),
    title = character(), host_organization = character(),
    source_type = character(), is_oa = logical(), is_in_doaj = logical(),
    oa_flip_year = integer(), works_count = integer()
  )
}

# ISSN to ISSN-L mapping. Starts from a known mapping, in order of priority,
# and extends it with the print/online ISSN pairs in the JCT journal lists:
# if one ISSN of a pair has an ISSN-L, the other gets the same one. An ISSN
# that the known mapping assigns to several ISSN-Ls keeps the first one.
build_issn_map <- function(issn_l_map, jct_jn) {
  known <- issn_l_map |>
    dplyr::transmute(
      issn = normalize_issn(.data$issn),
      issn_l = normalize_issn(.data$issn_l)
    ) |>
    dplyr::filter(!is.na(.data$issn), !is.na(.data$issn_l))
  # The ISSN-L is itself an ISSN of the journal
  known <- known |>
    dplyr::bind_rows(dplyr::distinct(known, issn = .data$issn_l, .data$issn_l)) |>
    dplyr::distinct(.data$issn, .keep_all = TRUE)

  pairs <- jct_jn |>
    dplyr::transmute(
      p = normalize_issn(.data$issn_print),
      o = normalize_issn(.data$issn_online)
    ) |>
    dplyr::filter(!is.na(.data$p), !is.na(.data$o), .data$p != .data$o) |>
    dplyr::distinct()
  via_print <- pairs |>
    dplyr::inner_join(known, by = c(p = "issn")) |>
    dplyr::transmute(issn = .data$o, .data$issn_l)
  via_online <- pairs |>
    dplyr::inner_join(known, by = c(o = "issn")) |>
    dplyr::transmute(issn = .data$p, .data$issn_l)
  extra <- dplyr::bind_rows(via_print, via_online) |>
    dplyr::filter(!.data$issn %in% known$issn) |>
    dplyr::arrange(.data$issn, .data$issn_l) |>
    dplyr::distinct(.data$issn, .keep_all = TRUE)

  dplyr::bind_rows(known, extra) |>
    dplyr::arrange(.data$issn)
}

# Agreement-journal links from the current JCT export and hoaddata 0.3
build_agreement_journals <- function(jct_jn, legacy_jct, issn_map, exclusions) {
  excluded <- exclusions$value[exclusions$type == "agreement_id"]

  jct <- jct_jn |>
    dplyr::mutate(issn_l = lookup_issn_l(.data$issn_print, .data$issn_online, issn_map))
  unmatched <- jct |>
    dplyr::filter(is.na(.data$issn_l)) |>
    dplyr::select("esac_id", "journal_name", "issn_print", "issn_online")

  current <- jct |>
    dplyr::filter(!is.na(.data$issn_l)) |>
    dplyr::group_by(agreement_id = .data$esac_id, .data$issn_l) |>
    dplyr::summarise(
      last_seen = as.Date(max(.data$time_last_seen)),
      .groups = "drop"
    )

  # The current JCT export is not a superset of the hoaddata 0.3 links: some
  # agreements dropped out, and some journal lists changed. Keeping the legacy
  # links means a journal, once listed, stays in the agreement.
  legacy <- legacy_jct |>
    dplyr::transmute(
      agreement_id = .data$esac_id,
      issn_l = normalize_issn(.data$issn_l),
      last_seen = as.Date(NA)
    )

  links <- dplyr::bind_rows(current, legacy) |>
    dplyr::filter(!is.na(.data$issn_l), !.data$agreement_id %in% excluded) |>
    dplyr::distinct(.data$agreement_id, .data$issn_l, .keep_all = TRUE) |>
    dplyr::arrange(.data$agreement_id, .data$issn_l)

  list(table = links, unmatched = unmatched)
}

lookup_issn_l <- function(issn_print, issn_online, issn_map) {
  dplyr::coalesce(
    issn_map$issn_l[match(normalize_issn(issn_print), issn_map$issn)],
    issn_map$issn_l[match(normalize_issn(issn_online), issn_map$issn)]
  )
}

# Agreements missing from ESAC get an inferred period: from 1 January of
# the year in their ID to the end of the year they were last listed in the
# JCT (`last_seen`: any table with `agreement_id` and `last_seen`).
build_agreements <- function(agreement_ids, esac, agreement_publishers,
                             publisher_names, last_seen = NULL) {
  prefix <- function(id) sub("[0-9]{4}.*$", "", id)
  suffix <- function(id) sub("^[a-z]+[0-9]{4}", "", id)

  # Publisher by ID prefix (e.g. `wiley`), for agreements missing from ESAC
  prefix_publishers <- esac |>
    dplyr::distinct(prefix = prefix(.data$id), .data$publisher) |>
    dplyr::bind_rows(agreement_publishers) |>
    dplyr::distinct(.data$prefix, .keep_all = TRUE)

  out <- tibble::tibble(agreement_id = agreement_ids) |>
    dplyr::left_join(esac, by = c(agreement_id = "id")) |>
    dplyr::mutate(
      publisher = dplyr::coalesce(
        .data$publisher,
        prefix_publishers$publisher[
          match(prefix(.data$agreement_id), prefix_publishers$prefix)
        ]
      ),
      publisher = normalize_publisher(.data$publisher, publisher_names),
      lead_institution = .data$organization,
      agreement_name = paste0(
        .data$publisher,
        " (",
        dplyr::coalesce(.data$organization, toupper(suffix(.data$agreement_id))),
        ")"
      ),
      country = country_iso2(.data$country),
      start_date = as.Date(.data$start_date),
      end_date = as.Date(.data$end_date)
    )

  seen <- if (is.null(last_seen)) {
    tibble::tibble(agreement_id = character(), seen_year = integer())
  } else {
    last_seen |>
      dplyr::filter(!is.na(.data$last_seen)) |>
      dplyr::group_by(.data$agreement_id) |>
      dplyr::summarise(seen_year = as.integer(format(max(.data$last_seen), "%Y")))
  }
  id_year <- suppressWarnings(as.integer(sub("^[a-z]+([0-9]{4}).*$", "\\1", out$agreement_id)))
  seen_year <- seen$seen_year[match(out$agreement_id, seen$agreement_id)]
  infer <- is.na(out$start_date) & is.na(out$end_date) & !is.na(id_year) & !is.na(seen_year)
  out$is_period_inferred <- infer
  out$start_date[infer] <- as.Date(paste0(id_year[infer], "-01-01"))
  out$end_date[infer] <- as.Date(paste0(pmax(seen_year[infer], id_year[infer]), "-12-31"))

  no_publisher <- out$agreement_id[is.na(out$publisher)]
  if (length(no_publisher) > 0) {
    cli::cli_abort(c(
      "Agreement{?s} without publisher: {.val {no_publisher}}",
      "i" = "Add the ID prefix to {.file manual/agreement_publishers.csv}."
    ))
  }

  out |>
    dplyr::select(dplyr::all_of(jn_schema("agreements")$column)) |>
    dplyr::arrange(.data$agreement_id)
}

# Participating institutions per agreement, from the current JCT export and
# hoaddata 0.3 (kept, as for journals). Rows without a valid ROR ID cannot be
# matched to OpenAlex and are reported separately.
build_agreement_institutions <- function(jct_inst, legacy_inst, agreement_ids) {
  rows <- dplyr::bind_rows(
    jct_inst |>
      dplyr::transmute(
        agreement_id = .data$esac_id,
        ror = normalize_ror(.data$ror_id),
        inst_name = trimws(.data$inst_name),
        last_seen = as.Date(.data$time_last_seen)
      ),
    legacy_inst |>
      dplyr::transmute(
        agreement_id = .data$esac_id,
        ror = normalize_ror(.data$ror_id),
        inst_name = trimws(.data$inst_name),
        last_seen = as.Date(NA)
      )
  ) |>
    dplyr::filter(.data$agreement_id %in% agreement_ids)

  no_ror <- rows |>
    dplyr::filter(is.na(.data$ror)) |>
    dplyr::distinct(.data$agreement_id, .data$inst_name)

  names <- rows |>
    dplyr::filter(!is.na(.data$ror), !is.na(.data$inst_name)) |>
    dplyr::count(.data$agreement_id, .data$ror, .data$inst_name) |>
    dplyr::arrange(.data$agreement_id, .data$ror, dplyr::desc(.data$n), .data$inst_name) |>
    dplyr::distinct(.data$agreement_id, .data$ror, .keep_all = TRUE)

  table <- rows |>
    dplyr::filter(!is.na(.data$ror)) |>
    dplyr::group_by(.data$agreement_id, .data$ror) |>
    dplyr::summarise(
      last_seen = if (all(is.na(.data$last_seen))) as.Date(NA) else max(.data$last_seen, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::left_join(names[c("agreement_id", "ror", "inst_name")], by = c("agreement_id", "ror")) |>
    dplyr::select(dplyr::all_of(jn_schema("agreement_institutions")$column)) |>
    dplyr::arrange(.data$agreement_id, .data$ror)

  list(table = table, no_ror = no_ror)
}

# `publisher` is the most frequent publisher among the agreements covering the
# journal. `title`, `openalex_source_id` and `oa_flip_year` come from the
# largest OpenAlex source with that ISSN-L; titles fall back to the most
# frequent JCT title, then the legacy title. `oa_model`: the curated list
# first, then `full_oa` if OpenAlex marks the source as OA or in DOAJ,
# `hybrid` if it is in OpenAlex otherwise, and `NA` if not in OpenAlex.
build_journals <- function(agreement_journals, agreements, jct_jn, issn_map,
                           legacy_titles, oa_models,
                           openalex = empty_openalex_sources()) {
  oalex <- openalex |>
    dplyr::mutate(issn_l = normalize_issn(.data$issn_l)) |>
    dplyr::arrange(.data$issn_l, dplyr::desc(.data$works_count)) |>
    dplyr::distinct(.data$issn_l, .keep_all = TRUE) |>
    dplyr::transmute(
      .data$issn_l,
      oa_title = .data$title,
      openalex_source_id = .data$openalex_source_id,
      oa_model_openalex = dplyr::if_else(
        dplyr::coalesce(.data$is_oa, FALSE) | dplyr::coalesce(.data$is_in_doaj, FALSE),
        "full_oa", "hybrid"
      ),
      oa_flip_year = .data$oa_flip_year
    )

  publishers <- agreement_journals |>
    dplyr::inner_join(agreements[c("agreement_id", "publisher")], by = "agreement_id") |>
    most_frequent("publisher")

  jct_titles <- jct_jn |>
    dplyr::mutate(
      issn_l = lookup_issn_l(.data$issn_print, .data$issn_online, issn_map),
      title = trimws(.data$journal_name)
    ) |>
    dplyr::filter(!is.na(.data$issn_l), !is.na(.data$title), .data$title != "") |>
    most_frequent("title")

  tibble::tibble(issn_l = sort(unique(agreement_journals$issn_l))) |>
    dplyr::left_join(publishers, by = "issn_l") |>
    dplyr::left_join(jct_titles, by = "issn_l") |>
    dplyr::left_join(oalex, by = "issn_l") |>
    dplyr::mutate(
      title = dplyr::coalesce(
        .data$oa_title,
        .data$title,
        legacy_titles$title[match(.data$issn_l, legacy_titles$issn_l)]
      ),
      oa_model = dplyr::coalesce(
        oa_models$oa_model[match(.data$issn_l, oa_models$issn_l)],
        .data$oa_model_openalex
      )
    ) |>
    dplyr::select(dplyr::all_of(jn_schema("journals")$column))
}

most_frequent <- function(df, col) {
  df |>
    dplyr::filter(!is.na(.data[[col]])) |>
    dplyr::count(.data$issn_l, .data[[col]]) |>
    dplyr::arrange(.data$issn_l, dplyr::desc(.data$n), .data[[col]]) |>
    dplyr::distinct(.data$issn_l, .keep_all = TRUE) |>
    dplyr::select("issn_l", dplyr::all_of(col))
}

build_journal_issns <- function(issn_map, journals) {
  issn_map |>
    dplyr::filter(.data$issn_l %in% journals$issn_l) |>
    dplyr::bind_rows(tibble::tibble(issn = journals$issn_l, issn_l = journals$issn_l)) |>
    dplyr::distinct(.data$issn, .keep_all = TRUE) |>
    dplyr::arrange(.data$issn)
}

# A portfolio (dashboard page) is the set of agreements of one publisher.
# Its journals follow from `agreement_journals`.
build_portfolios <- function(portfolio_config, agreements, agreement_journals,
                             publisher_names) {
  config <- portfolio_config |>
    dplyr::distinct() |>
    dplyr::mutate(
      publisher = normalize_publisher(.data$portfolio_label, publisher_names),
      portfolio_id = slugify(.data$publisher)
    )

  with_journals <- agreements[agreements$agreement_id %in% agreement_journals$agreement_id, ]
  out <- config |>
    dplyr::inner_join(with_journals, by = "publisher", relationship = "one-to-many") |>
    dplyr::distinct(.data$portfolio_id, .data$portfolio_label, .data$agreement_id)

  empty <- setdiff(config$portfolio_id, out$portfolio_id)
  if (length(empty) > 0) {
    cli::cli_abort("Portfolio{?s} without agreements: {.val {empty}}")
  }
  # Keep the page order of the configuration
  out |>
    dplyr::mutate(.order = match(.data$portfolio_id, config$portfolio_id)) |>
    dplyr::arrange(.data$.order, .data$agreement_id) |>
    dplyr::select(-".order")
}

#' Save the reference tables as package data
#'
#' Writes each reference table to `dir` as an xz-compressed `.rda` file, as
#' `usethis::use_data()` would, but without needing an active project (for
#' example in GitHub Actions).
#'
#' @param ref The list returned by [jn_update_reference()].
#' @param dir The package's `data/` directory.
#' @return The written file paths, invisibly.
#' @export
jn_save_reference <- function(ref, dir = "data") {
  tables <- c(
    "journals", "journal_issns", "agreements", "agreement_journals",
    "agreement_institutions", "portfolios"
  )
  dir.create(dir, showWarnings = FALSE)
  files <- vapply(tables, function(name) {
    file <- file.path(dir, paste0(name, ".rda"))
    env <- new.env()
    assign(name, ref[[name]], envir = env)
    save(list = name, file = file, envir = env, compress = "xz")
    file
  }, "")
  invisible(unname(files))
}
