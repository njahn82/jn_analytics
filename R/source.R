#' Connect to the jnanalytics tables
#'
#' The analysis functions read from a source: a folder of Parquet files as
#' downloaded by [jn_download()] (which returns its source, so most users
#' never call `jn_source()`) or written by [jn_publish()], or the BigQuery
#' dataset. A table is either one file (`journal_year.parquet`) or a folder
#' of files (`articles/articles_2025.parquet`, ...); a download of only some
#' tables or years works too.
#'
#' For a folder from [jn_download()], `jn_source()` says once per session if
#' a newer release is available. Turn this off with
#' `options(jnanalytics.check_updates = FALSE)`.
#'
#' @param x A directory with Parquet files, or `"bigquery"`.
#' @param config See [jn_bq_config()]. Used for BigQuery only.
#'
#' @return A `jn_source` object. `jn_tbl()` returns one of its tables as a
#'   lazy table that dplyr verbs can be applied to.
#' @export
#' @examples
#' \dontrun{
#' src <- jn_source("my_data")
#' jn_tbl(src, "journal_year")
#' jn_tbl(src, "articles") |>
#'   dplyr::filter(issn_l == "0360-0300", pub_year == 2025) |>
#'   dplyr::collect()
#'
#' bq <- jn_source("bigquery")
#' jn_tbl(bq, "articles") |>
#'   dplyr::filter(issn_l == "0360-0300", pub_year == 2025) |>
#'   dplyr::collect()
#' }
jn_source <- function(x = "parquet", config = jn_bq_config()) {
  if (identical(x, "bigquery")) {
    rlang::check_installed(c("bigrquery", "DBI", "dbplyr"))
    con <- DBI::dbConnect(
      bigrquery::bigquery(),
      project = config$project,
      dataset = config$dataset,
      billing = config$billing
    )
    return(structure(
      list(type = "bigquery", con = con, tables = jn_tables()),
      class = "jn_source"
    ))
  }
  rlang::check_installed("arrow")
  if (!dir.exists(x)) {
    cli::cli_abort("Directory {.path {x}} not found. Download the data with {.fn jn_download} first.")
  }
  check_download_update(x)
  tables <- intersect(jn_tables(), unique(export_files(x)$table))
  structure(
    list(type = "parquet", path = x, tables = tables),
    class = "jn_source"
  )
}

#' @rdname jn_source
#' @param src A `jn_source`.
#' @param table Table name, see [jn_tables()].
#' @export
jn_tbl <- function(src, table) {
  check_table_name(table)
  if (!table %in% src$tables) {
    cli::cli_abort(c(
      "Table {.val {table}} is not in this source.",
      "i" = "Available: {.val {src$tables}}"
    ))
  }
  if (src$type == "bigquery") {
    return(dplyr::tbl(src$con, table))
  }
  file <- file.path(src$path, paste0(table, ".parquet"))
  arrow::open_dataset(if (file.exists(file)) file else file.path(src$path, table))
}

#' @export
print.jn_source <- function(x, ...) {
  where <- if (x$type == "parquet") x$path else "BigQuery"
  cli::cli_text("jnanalytics source ({x$type}): {where}")
  cli::cli_text("Tables: {.val {x$tables}}")
  invisible(x)
}
