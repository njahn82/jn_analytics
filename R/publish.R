#' Describe a release
#'
#' One-row `release` table: package version, build date, the Crossref,
#' OpenAlex and Journal Checker Tool snapshots used, and the publication years
#' covered.
#'
#' @param journal_year The `journal_year` table, for the years covered.
#' @param raw_dir Directory with `jct_jn_all.csv.gz`.
#' @param config See [jn_bq_config()].
#'
#' @return A tibble matching `jn_schema("release")`.
#' @export
jn_release <- function(journal_year, raw_dir = "data-raw", config = jn_bq_config()) {
  rlang::check_installed("bigrquery")
  jct <- readr::read_csv(
    file.path(raw_dir, "jct_jn_all.csv.gz"),
    col_types = readr::cols_only(time_last_seen = readr::col_datetime()),
    show_col_types = FALSE, progress = FALSE
  )
  snapshots <- jn_snapshots(config)
  release <- tibble::tibble(
    version = as.character(utils::packageVersion("jnanalytics")),
    snapshot_date = Sys.Date(),
    crossref_snapshot = snapshots$crossref,
    openalex_snapshot = snapshots$openalex,
    jct_snapshot = format(as.Date(max(jct$time_last_seen, na.rm = TRUE))),
    pub_year_min = min(journal_year$pub_year),
    pub_year_max = max(journal_year$pub_year)
  )
  jn_validate(release, "release")
}

# "Snapshot date: ..." from a BigQuery table description
bq_snapshot_date <- function(dataset, table) {
  parts <- strsplit(dataset, ".", fixed = TRUE)[[1]]
  meta <- bigrquery::bq_table_meta(bigrquery::bq_table(parts[1], parts[2], table))
  date <- regmatches(
    meta$description %||% "",
    regexpr("(?<=Snapshot date: )[0-9/-]+", meta$description %||% "", perl = TRUE)
  )
  if (length(date) == 0) NA_character_ else date
}

#' Export the published tables as Parquet
#'
#' Downloads the reference tables and the journal-level aggregates from
#' BigQuery, validates them against [jn_schema()] and writes one
#' zstd-compressed Parquet file per table to `path`, plus a `release` table
#' that is also uploaded to BigQuery. Article-level tables stay in BigQuery.
#'
#' Each file carries its table name, the package version and the column
#' descriptions as Parquet key-value metadata (`jn_table`, `jn_version`,
#' `jn_columns` as JSON), readable for example with DuckDB's
#' `parquet_kv_metadata()`.
#'
#' @param path Directory to write to, e.g. the dashboard's `docs/data/`.
#' @param tables Tables to export.
#' @param raw_dir,config See [jn_release()].
#'
#' @return The written file paths, invisibly.
#' @export
jn_publish <- function(path, tables = jn_publish_tables(),
                         raw_dir = "data-raw", config = jn_bq_config()) {
  rlang::check_installed(c("bigrquery", "arrow"))
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  data <- lapply(rlang::set_names(tables), function(name) {
    tbl <- bigrquery::bq_table(config$project, config$dataset, name)
    x <- bigrquery::bq_table_download(tbl, bigint = "integer", quiet = TRUE)
    x <- coerce_to_schema(x, name)
    jn_validate(x, name)
    cli::cli_inform("Downloaded {.val {name}} ({nrow(x)} rows).")
    x
  })

  if ("journal_year" %in% names(data)) {
    data$release <- jn_release(data$journal_year, raw_dir, config)
    bigrquery::bq_table_upload(
      bigrquery::bq_table(config$project, config$dataset, "release"),
      values = as.data.frame(data$release),
      fields = jn_bq_fields("release"),
      create_disposition = "CREATE_IF_NEEDED",
      write_disposition = "WRITE_TRUNCATE"
    )
  }

  files <- vapply(names(data), function(name) {
    file <- file.path(path, paste0(name, ".parquet"))
    write_jn_parquet(data[[name]], name, file)
    file
  }, "")
  sizes <- round(file.size(files) / 1e6, 1)
  cli::cli_inform(c(
    "Wrote {length(files)} Parquet file{?s} to {.path {path}} ({sum(sizes)} MB).",
    rlang::set_names(paste0(basename(files), ": ", sizes, " MB"), rep("*", length(files)))
  ))
  invisible(files)
}

#' Tables exported by [jn_publish()]
#' @return A character vector of table names.
#' @export
jn_publish_tables <- function() {
  c(
    "journals", "journal_issns", "agreements", "agreement_journals",
    "agreement_institutions", "portfolios", "journal_year",
    "journal_year_country", "journal_year_license",
    "journal_year_country_license", "agreement_journal_year"
  )
}

# Bring downloaded columns to the schema types and order
coerce_to_schema <- function(x, table) {
  schema <- jn_schema(table)
  cast <- list(
    string = as.character, integer = as.integer,
    boolean = as.logical, date = as.Date
  )
  for (i in seq_len(nrow(schema))) {
    col <- schema$column[i]
    if (col %in% names(x)) {
      x[[col]] <- cast[[schema$type[i]]](x[[col]])
    }
  }
  tibble::as_tibble(x[intersect(schema$column, names(x))])
}

write_jn_parquet <- function(x, table, file) {
  schema <- jn_schema(table)
  arrow_table <- arrow::arrow_table(x)
  arrow_table$metadata$jn_table <- table
  arrow_table$metadata$jn_version <- as.character(utils::packageVersion("jnanalytics"))
  arrow_table$metadata$jn_columns <- as.character(jsonlite::toJSON(
    as.list(rlang::set_names(schema$description, schema$column)),
    auto_unbox = TRUE
  ))
  arrow::write_parquet(arrow_table, file, compression = "zstd")
  invisible(file)
}
