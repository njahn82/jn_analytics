#' Upload the reference tables to BigQuery
#'
#' Writes `journals`, `journal_issns`, `agreements`, `agreement_journals`,
#' `agreement_institutions` and `portfolios` to the jnanalytics dataset, replacing existing tables. Column
#' types and descriptions come from [jn_schema()]. Load jobs are free.
#'
#' @param ref Named list of reference tables. Defaults to the bundled data.
#'   With all six tables, foreign keys between them are checked too.
#' @param config See [jn_bq_config()].
#'
#' @return The BigQuery tables, invisibly.
#' @export
jn_upload_reference <- function(ref = NULL, config = jn_bq_config()) {
  rlang::check_installed("bigrquery")
  if (is.null(ref)) {
    tables <- c(
      "journals", "journal_issns", "agreements", "agreement_journals",
      "agreement_institutions", "portfolios"
    )
    ref <- rlang::set_names(lapply(tables, \(t) getExportedValue("jnanalytics", t)), tables)
  }
  all_tables <- c(
    "journals", "journal_issns", "agreements", "agreement_journals",
    "agreement_institutions", "portfolios"
  )
  if (all(all_tables %in% names(ref))) {
    validate_reference(ref)
  } else {
    for (name in names(ref)) jn_validate(ref[[name]], name)
  }

  out <- lapply(names(ref), function(name) {
    tbl <- bigrquery::bq_table(config$project, config$dataset, name)
    bigrquery::bq_table_upload(
      tbl,
      values = as.data.frame(ref[[name]]),
      fields = jn_bq_fields(name),
      create_disposition = "CREATE_IF_NEEDED",
      write_disposition = "WRITE_TRUNCATE"
    )
    cli::cli_inform("Uploaded {.val {name}} ({nrow(ref[[name]])} rows).")
    tbl
  })
  invisible(rlang::set_names(out, names(ref)))
}

#' Build a table in BigQuery from a SQL template
#'
#' Renders `inst/sql/<name>.sql` with [jn_sql()], reports the bytes the
#' query will scan, writes the result to `<project>.<dataset>.<name>`
#' (replacing it) and sets the column descriptions from [jn_schema()].
#'
#' @param name Table and template name, e.g. `"articles"`.
#' @param config See [jn_bq_config()].
#' @param year_min,year_max Publication years covered.
#' @param max_gb Stop without running if the query would scan more than this.
#' @param dry_run If `TRUE`, only report the bytes that would be scanned.
#'
#' @return The BigQuery table, invisibly (or the bytes, for a dry run).
#' @export
jn_build_table <- function(name, config = jn_bq_config(), year_min = 2016L,
                             year_max = as.integer(format(Sys.Date(), "%Y")),
                             max_gb = 200, dry_run = FALSE) {
  rlang::check_installed("bigrquery")
  check_table_name(name)
  sql <- jn_sql(name, config, year_min = year_min, year_max = year_max)

  bytes <- bigrquery::bq_perform_query_dry_run(sql, billing = config$billing)
  gb <- as.numeric(bytes) / 1e9
  cli::cli_inform("{.val {name}}: query scans {round(gb, 1)} GB.")
  if (dry_run) {
    return(invisible(bytes))
  }
  if (gb > max_gb) {
    cli::cli_abort(c(
      "Query for {.val {name}} would scan {round(gb, 1)} GB, more than {.arg max_gb} = {max_gb}.",
      "i" = "Raise {.arg max_gb} to run it anyway."
    ))
  }

  tbl <- bigrquery::bq_table(config$project, config$dataset, name)
  bigrquery::bq_project_query(
    config$billing, sql,
    destination_table = tbl,
    create_disposition = "CREATE_IF_NEEDED",
    write_disposition = "WRITE_TRUNCATE"
  )
  set_bq_descriptions(tbl, name)
  meta <- bigrquery::bq_table_meta(tbl)
  cli::cli_inform("Built {.val {name}}: {meta$numRows} rows.")
  invisible(tbl)
}

#' BigQuery fields for a jnanalytics table
#'
#' @param table Table name, see [jn_tables()].
#' @return A `bq_fields` object with types and descriptions from the schema.
#' @export
jn_bq_fields <- function(table) {
  rlang::check_installed("bigrquery")
  schema <- jn_schema(table)
  types <- c(string = "STRING", integer = "INTEGER", boolean = "BOOLEAN", date = "DATE")
  bigrquery::as_bq_fields(lapply(seq_len(nrow(schema)), function(i) {
    bigrquery::bq_field(
      schema$column[i],
      types[[schema$type[i]]],
      description = schema$description[i]
    )
  }))
}

# Copy column descriptions from the schema onto a table built by a query,
# keeping the types BigQuery inferred
set_bq_descriptions <- function(tbl, name) {
  schema <- jn_schema(name)
  fields <- bigrquery::bq_table_fields(tbl)
  missing <- setdiff(schema$column, vapply(fields, `[[`, "", "name"))
  if (length(missing) > 0) {
    cli::cli_abort("Table {.val {name}} lacks schema column{?s} {.field {missing}}.")
  }
  fields <- lapply(fields, function(f) {
    f$description <- schema$description[match(f$name, schema$column)]
    f
  })
  bigrquery::bq_table_patch(tbl, bigrquery::as_bq_fields(fields))
}

#' Build all jnanalytics tables in BigQuery
#'
#' Uploads the reference tables, then builds the article tables and the
#' aggregates in dependency order: `articles`, `article_first_authors`,
#' `journal_year`, `journal_year_country`, `journal_year_license`,
#' `journal_year_country_license`, `article_agreements` and
#' `agreement_journal_year`.
#'
#' @inheritParams jn_build_table
#' @param tables Tables to build, in this order. Defaults to all.
#' @param upload If `TRUE`, upload the reference tables first.
#'
#' @return The built BigQuery tables, invisibly.
#' @export
jn_build <- function(config = jn_bq_config(), year_min = 2016L,
                       year_max = as.integer(format(Sys.Date(), "%Y")),
                       tables = jn_build_order(),
                       upload = TRUE, max_gb = 200) {
  unknown <- setdiff(tables, jn_build_order())
  if (length(unknown) > 0) {
    cli::cli_abort("Unknown table{?s} to build: {.val {unknown}}")
  }
  if (upload) {
    jn_upload_reference(config = config)
  }
  out <- lapply(intersect(jn_build_order(), tables), function(name) {
    jn_build_table(
      name, config,
      year_min = year_min, year_max = year_max, max_gb = max_gb
    )
  })
  invisible(out)
}

jn_build_order <- function() {
  c(
    "articles", "article_first_authors", "journal_year",
    "journal_year_country", "journal_year_license",
    "journal_year_country_license", "article_agreements",
    "agreement_journal_year"
  )
}
