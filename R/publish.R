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
#' Downloads tables from BigQuery, validates them against [jn_schema()] and
#' writes zstd-compressed Parquet files to `path`, in the layout of the
#' Hugging Face dataset (see [jn_upload_hf()]):
#'
#' - one file per table for the reference tables and the journal-level
#'   aggregates, e.g. `journal_year.parquet`, plus a `release` table (written
#'   with `journal_year` and also uploaded to BigQuery);
#' - one folder per article table with one file per publication year, e.g.
#'   `articles/articles_2025.parquet`. These are read year by year from the
#'   tables partitioned by `pub_year` (see [jn_build_table()]), so each query
#'   scans only that year. Old files in the folder are removed first.
#'
#' Each file carries its table name, the package version and the column
#' descriptions as Parquet key-value metadata (`jn_table`, `jn_version`,
#' `jn_columns` as JSON), readable for example with DuckDB's
#' `parquet_kv_metadata()`.
#'
#' @param path Directory to write to.
#' @param tables Tables to export, see [jn_publish_tables()].
#' @param raw_dir,config See [jn_release()].
#' @param max_gb Stop before exporting an article table whose queries would
#'   scan more than this.
#'
#' @return The written file paths, invisibly.
#' @export
jn_publish <- function(path, tables = jn_publish_tables(),
                         raw_dir = "data-raw", config = jn_bq_config(),
                         max_gb = 30) {
  rlang::check_installed(c("bigrquery", "arrow", "jsonlite"))
  unknown <- setdiff(tables, jn_publish_tables())
  if (length(unknown) > 0) {
    cli::cli_abort("Unknown table{?s} to export: {.val {unknown}}")
  }
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  whole <- setdiff(tables, jn_article_tables())
  data <- lapply(rlang::set_names(whole), function(name) {
    tbl <- bigrquery::bq_table(config$project, config$dataset, name)
    x <- bq_download(tbl)
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
  for (name in intersect(tables, jn_article_tables())) {
    files <- c(files, publish_by_year(name, path, config, max_gb, call = rlang::current_env()))
  }
  files <- unname(files)

  sizes <- round(file.size(files) / 1e6, 1)
  cli::cli_inform(c(
    "Wrote {length(files)} Parquet file{?s} to {.path {path}} ({sum(sizes)} MB).",
    rlang::set_names(
      paste0(substring(files, nchar(path) + 2), ": ", sizes, " MB"),
      rep("*", length(files))
    )
  ))
  invisible(files)
}

#' Tables exported by [jn_publish()]
#'
#' All tables of the data model except `release`, which [jn_publish()]
#' writes together with `journal_year`.
#'
#' @return A character vector of table names.
#' @export
jn_publish_tables <- function() {
  c(
    "journals", "journal_issns", "agreements", "agreement_journals",
    "agreement_institutions", "portfolios", "journal_year",
    "journal_year_country", "journal_year_license",
    "journal_year_country_license", "agreement_journal_year",
    jn_article_tables()
  )
}

# Write one Parquet file per publication year of an article table
publish_by_year <- function(name, path, config, max_gb, call = rlang::caller_env()) {
  years <- bq_partition_years(name, config)
  if (length(years) == 0) {
    cli::cli_abort(c(
      "Table {.val {name}} has no year partitions in BigQuery.",
      "i" = "Rebuild it with {.fn jn_build_table}, which partitions it by {.field pub_year}."
    ), call = call)
  }
  queries <- year_queries(name, years, config)
  bytes <- vapply(queries, function(sql) {
    as.numeric(bigrquery::bq_perform_query_dry_run(sql, billing = config$billing))
  }, numeric(1))
  gb <- sum(bytes) / 1e9
  cli::cli_inform(
    "{.val {name}}: {length(years)} year{?s} ({min(years)}-{max(years)}), queries scan {round(gb, 1)} GB."
  )
  if (gb > max_gb) {
    cli::cli_abort(c(
      "Export of {.val {name}} would scan {round(gb, 1)} GB, more than {.arg max_gb} = {max_gb}.",
      "i" = "Is the table partitioned by {.field pub_year}? Raise {.arg max_gb} to run it anyway."
    ), call = call)
  }

  dir <- file.path(path, name)
  unlink(dir, recursive = TRUE)
  dir.create(dir, recursive = TRUE)
  vapply(seq_along(years), function(i) {
    tbl <- bigrquery::bq_project_query(config$billing, queries[[i]])
    x <- coerce_to_schema(bq_download(tbl), name)
    jn_validate(x, name)
    file <- file.path(dir, sprintf("%s_%d.parquet", name, years[i]))
    write_jn_parquet(x, name, file)
    cli::cli_inform("Downloaded {.val {name}} {years[i]} ({nrow(x)} rows).")
    file
  }, "")
}

year_queries <- function(name, years, config) {
  sprintf(
    "SELECT * FROM `%s.%s.%s` WHERE pub_year = %d",
    config$project, config$dataset, name, as.integer(years)
  )
}

# Non-empty year partitions of a table, from INFORMATION_SCHEMA (metadata
# only, billed as 10 MB)
bq_partition_years <- function(name, config) {
  sql <- sprintf(
    "SELECT partition_id FROM `%s.%s.INFORMATION_SCHEMA.PARTITIONS`
     WHERE table_name = '%s' AND total_rows > 0",
    config$project, config$dataset, name
  )
  ids <- bigrquery::bq_project_query(config$billing, sql) |>
    bigrquery::bq_table_download(quiet = TRUE)
  outside <- ids$partition_id[ids$partition_id %in% c("__NULL__", "__UNPARTITIONED__")]
  if (length(outside) > 0) {
    cli::cli_warn("{.val {name}} has rows without a year partition ({.val {outside}}); they are not exported.")
  }
  partition_years(ids$partition_id)
}

partition_years <- function(ids) {
  ids <- ids[!is.na(ids) & grepl("^[0-9]{4}$", ids)]
  sort(as.integer(ids))
}

bq_download <- function(tbl) {
  bigrquery::bq_table_download(tbl, bigint = "integer", quiet = TRUE)
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
