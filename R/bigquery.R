#' BigQuery locations used by the build
#'
#' All tables built by jnanalytics go into one dataset. Inputs come from the
#' Crossref and OpenAlex snapshots in `subugoe-collaborative` only.
#'
#' @param project,dataset Where jnanalytics writes its tables.
#' @param openalex,crossref Fully qualified datasets with the OpenAlex
#'   (Walden) and Crossref snapshots.
#' @param billing Project billed for queries.
#'
#' @return A named list, used as default by the build functions.
#' @export
#' @examples
#' jn_bq_config()
jn_bq_config <- function(project = "subugoe-collaborative",
                           dataset = "jn_analytics",
                           openalex = "subugoe-collaborative.openalex_walden",
                           crossref = "subugoe-collaborative.cr_instant",
                           billing = project) {
  list(
    project = project,
    dataset = dataset,
    openalex = openalex,
    crossref = crossref,
    billing = billing
  )
}

#' Render a SQL template from `inst/sql`
#'
#' Replaces `{{name}}` placeholders. `{{dataset}}`, `{{openalex}}` and
#' `{{crossref}}` come from `config`; `{{year_min}}` and `{{year_max}}` from
#' the arguments.
#'
#' @param name Basename of the SQL file, e.g. `"articles"`.
#' @param config See [jn_bq_config()].
#' @param year_min,year_max Publication years covered.
#'
#' @return The SQL as a single string.
#' @export
#' @examples
#' cat(jn_sql("openalex_sources"))
jn_sql <- function(name, config = jn_bq_config(), year_min = 2016L,
                     year_max = as.integer(format(Sys.Date(), "%Y"))) {
  path <- system.file("sql", paste0(name, ".sql"), package = "jnanalytics")
  if (path == "") {
    cli::cli_abort("SQL template {.file {name}.sql} not found in {.path inst/sql}.")
  }
  sql <- paste(readLines(path, encoding = "UTF-8"), collapse = "\n")
  values <- c(
    dataset = paste0(config$project, ".", config$dataset),
    openalex = config$openalex,
    crossref = config$crossref,
    year_min = year_min,
    year_max = year_max
  )
  for (key in names(values)) {
    sql <- gsub(paste0("{{", key, "}}"), values[[key]], sql, fixed = TRUE)
  }
  left <- unique(regmatches(sql, gregexpr("\\{\\{[a-z_]+\\}\\}", sql))[[1]])
  if (length(left) > 0) {
    cli::cli_abort("Unknown placeholder{?s} in {.file {name}.sql}: {.val {left}}")
  }
  sql
}

#' Fetch OpenAlex journal metadata for the JCT journals
#'
#' Downloads ISSN, ISSN-L, title and open access status of all OpenAlex
#' sources with an ISSN-L, keeps the sources sharing an ISSN with a current or
#' legacy JCT journal list, and writes them to `openalex_sources.csv` in
#' `raw_dir`.
#' [jn_update_reference()] then uses this file to assign ISSN-Ls and to
#' classify journals as hybrid or fully open access.
#'
#' The query reads only the small `sources` table (about 20 MB).
#'
#' @param raw_dir Directory with `jct_jn_all.csv.gz`; the result is written here.
#' @param config See [jn_bq_config()].
#'
#' @return The path to the written file, invisibly.
#' @export
jn_fetch_openalex_sources <- function(raw_dir = "data-raw", config = jn_bq_config()) {
  rlang::check_installed("bigrquery")
  sources <- bigrquery::bq_project_query(config$billing, jn_sql("openalex_sources", config)) |>
    bigrquery::bq_table_download()

  out <- filter_jct_sources(sources, jct_issns(raw_dir))
  path <- file.path(raw_dir, "openalex_sources.csv")
  readr::write_csv(out, path, na = "")
  cli::cli_inform(
    "Wrote {nrow(out)} rows for {length(unique(out$issn_l))} journals to {.file {path}}."
  )
  invisible(path)
}

# All ISSNs in the current and legacy JCT journal lists
jct_issns <- function(raw_dir) {
  read <- function(file) {
    readr::read_csv(
      file.path(raw_dir, file),
      col_types = readr::cols(.default = readr::col_character()),
      show_col_types = FALSE, progress = FALSE
    )
  }
  jct <- read("jct_jn_all.csv.gz")
  legacy <- read("legacy/jct_hybrid_jns.csv.gz")
  unique(c(jct$issn_print, jct$issn_online, legacy$issn, legacy$issn_l))
}

# Keep every ISSN of the sources that share at least one ISSN with the JCT
filter_jct_sources <- function(sources, jct_issns) {
  sources <- dplyr::mutate(
    sources,
    issn = normalize_issn(.data$issn),
    issn_l = normalize_issn(.data$issn_l)
  )
  hit <- unique(sources$openalex_source_id[sources$issn %in% normalize_issn(jct_issns)])
  sources |>
    dplyr::filter(.data$openalex_source_id %in% hit, !is.na(.data$issn), !is.na(.data$issn_l)) |>
    dplyr::distinct() |>
    dplyr::arrange(.data$issn_l, .data$issn)
}

#' Authenticate with BigQuery
#'
#' Uses the service-account key in `GOOGLE_APPLICATION_CREDENTIALS` when that
#' variable points to a file (as in GitHub Actions), and otherwise the cached
#' user login of `bigrquery`/`gargle`.
#'
#' @return `TRUE`, invisibly.
#' @export
jn_bq_auth <- function() {
  rlang::check_installed("bigrquery")
  key <- Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS")
  if (nzchar(key) && file.exists(key)) {
    bigrquery::bq_auth(path = key)
  } else {
    bigrquery::bq_auth(email = getOption("gargle_oauth_email", TRUE))
  }
  invisible(TRUE)
}

#' Snapshot dates of the input datasets
#'
#' Reads the "Snapshot date" from the descriptions of the Crossref and
#' OpenAlex tables. The pipeline rebuilds the BigQuery tables when they change.
#'
#' @param config See [jn_bq_config()].
#' @return A list with `crossref` and `openalex`.
#' @export
jn_snapshots <- function(config = jn_bq_config()) {
  rlang::check_installed("bigrquery")
  list(
    crossref = bq_snapshot_date(config$crossref, "snapshot"),
    openalex = bq_snapshot_date(config$openalex, "works")
  )
}
