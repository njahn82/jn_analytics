#' Connect to the jnanalytics tables
#'
#' The analysis functions read from a source: the Parquet files written by
#' [jn_publish()] (journal-level tables only), or the BigQuery dataset
#' (all tables, including the article-level `articles` and
#' `article_first_authors`).
#'
#' @param x A directory with Parquet files, or `"bigquery"`.
#' @param config See [jn_bq_config()]. Used for BigQuery only.
#'
#' @return A `jn_source` object. `jn_tbl()` returns one of its tables as a
#'   lazy table that dplyr verbs can be applied to.
#' @export
#' @examples
#' \dontrun{
#' src <- jn_source("parquet")
#' jn_tbl(src, "journal_year")
#'
#' # Article-level data is only in BigQuery
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
    cli::cli_abort("Directory {.path {x}} not found. Run {.fn jn_publish} first.")
  }
  files <- list.files(x, pattern = "\\.parquet$")
  structure(
    list(type = "parquet", path = x, tables = sub("\\.parquet$", "", files)),
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
    hint <- if (src$type == "parquet" && table %in% c("articles", "article_first_authors")) {
      "Article-level tables are only in BigQuery: use {.code jn_source(\"bigquery\")}."
    } else {
      "Available: {.val {src$tables}}"
    }
    cli::cli_abort(c("Table {.val {table}} is not in this source.", "i" = hint))
  }
  switch(src$type,
    parquet = arrow::open_dataset(file.path(src$path, paste0(table, ".parquet"))),
    bigquery = dplyr::tbl(src$con, table)
  )
}

#' @export
print.jn_source <- function(x, ...) {
  where <- if (x$type == "parquet") x$path else "BigQuery"
  cli::cli_text("jnanalytics source ({x$type}): {where}")
  cli::cli_text("Tables: {.val {x$tables}}")
  invisible(x)
}
