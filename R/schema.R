#' Column schema of the jnanalytics data model
#'
#' Returns the column definitions of all tables in the jnanalytics data model. The
#' schema is the single source of truth for column names, types and
#' descriptions: it is used to validate tables, to document the bundled data
#' and to set column descriptions in BigQuery and Parquet.
#'
#' @param table Optional table name. If `NULL`, the columns of all tables are
#'   returned.
#'
#' @return A tibble with the columns `table`, `column`, `type`, `key`,
#'   `references` and `description`.
#' @export
#' @examples
#' jn_schema("journals")
jn_schema <- function(table = NULL) {
  schema <- read_schema()
  if (is.null(table)) {
    return(schema)
  }
  check_table_name(table, schema)
  schema[schema$table == table, , drop = FALSE]
}

#' Tables in the jnanalytics data model
#'
#' @return A character vector of table names, in the order of the schema.
#' @export
#' @examples
#' jn_tables()
jn_tables <- function() {
  unique(read_schema()$table)
}

#' Validate a table against the jnanalytics schema
#'
#' Checks that a data frame has exactly the columns of `table` in schema order,
#' that every column has the expected type, and that the key columns are
#' complete and unique. Identifier formats are checked where a rule exists
#' (`issn_l`, `issn`, `doi`, `ror`, `country_code`, `cc_license`,
#' `oa_model`, `oa_status`, `work_type`, OpenAlex IDs).
#'
#' @param x A data frame.
#' @param table Table name, see [jn_tables()].
#'
#' @return `x`, invisibly. An error is raised listing every problem found.
#' @export
#' @examples
#' jn_validate(journals, "journals")
jn_validate <- function(x, table) {
  schema <- jn_schema(table)
  problems <- character()

  expected <- schema$column
  if (!identical(names(x), expected)) {
    problems <- c(problems, sprintf(
      "Columns must be %s, not %s.",
      paste0("`", expected, "`", collapse = ", "),
      paste0("`", names(x), "`", collapse = ", ")
    ))
  }

  for (i in seq_len(nrow(schema))) {
    col <- schema$column[i]
    if (!col %in% names(x)) next
    if (!has_type(x[[col]], schema$type[i])) {
      problems <- c(problems, sprintf(
        "`%s` must be %s, not %s.", col, schema$type[i], class(x[[col]])[1]
      ))
    }
    bad <- invalid_values(x[[col]], col)
    if (length(bad) > 0) {
      problems <- c(problems, sprintf(
        "`%s` has %d value(s) in a non-canonical form, e.g. %s.",
        col, length(bad), paste0("'", utils::head(bad, 3), "'", collapse = ", ")
      ))
    }
  }

  keys <- intersect(schema$column[schema$key], names(x))
  if (length(keys) > 0) {
    # NA is a valid level for cc_license in count tables, and a first author
    # can have a country without a ROR, so only the other keys must be
    # complete
    must_be_complete <- setdiff(keys, c("cc_license", "ror"))
    for (col in must_be_complete) {
      n_na <- sum(is.na(x[[col]]))
      if (n_na > 0) {
        problems <- c(problems, sprintf("Key `%s` has %d missing value(s).", col, n_na))
      }
    }
    n_dup <- sum(duplicated(x[keys]))
    if (n_dup > 0) {
      problems <- c(problems, sprintf(
        "Key (%s) has %d duplicated row(s).", paste(keys, collapse = ", "), n_dup
      ))
    }
  }

  if (length(problems) > 0) {
    cli::cli_abort(c(
      "Table {.val {table}} does not match the jnanalytics schema.",
      rlang::set_names(problems, rep("x", length(problems)))
    ))
  }
  invisible(x)
}

# Check foreign keys between two tables
#
# @param x,y Data frames.
# @param by Column name present in both `x` and `y`.
# @param x_name,y_name Names used in the error message.
#
# @return `x`, invisibly. An error is raised if `x[[by]]` has values that are
#   missing from `y[[by]]`.
check_foreign_key <- function(x, y, by, x_name, y_name) {
  orphans <- setdiff(stats::na.omit(unique(x[[by]])), y[[by]])
  if (length(orphans) > 0) {
    cli::cli_abort(c(
      "{.field {x_name}.{by}} has {length(orphans)} value{?s} missing from {.field {y_name}}.",
      "i" = "First: {.val {utils::head(orphans, 3)}}"
    ))
  }
  invisible(x)
}

read_schema <- function() {
  path <- system.file("schema", "columns.csv", package = "jnanalytics", mustWork = TRUE)
  schema <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
  schema$key <- as.logical(schema$key)
  schema$references[is.na(schema$references)] <- ""
  tibble::as_tibble(schema)
}

check_table_name <- function(table, schema = read_schema()) {
  if (!is.character(table) || length(table) != 1 || !table %in% schema$table) {
    cli::cli_abort(c(
      "{.arg table} must be one of the jnanalytics tables.",
      "i" = "Available: {.val {unique(schema$table)}}"
    ))
  }
}

has_type <- function(x, type) {
  switch(type,
    string = is.character(x),
    integer = is.integer(x),
    boolean = is.logical(x),
    date = inherits(x, "Date"),
    FALSE
  )
}

# Licences allowed in `cc_license`, ordered by permissiveness
cc_licenses <- c("CC BY", "CC BY-SA", "CC BY-NC", "CC BY-NC-SA", "CC BY-ND", "CC BY-NC-ND")

invalid_values <- function(x, column) {
  x <- unique(stats::na.omit(x))
  if (!is.character(x)) return(character())
  ok <- switch(column,
    issn_l = ,
    issn = grepl("^[0-9]{4}-[0-9]{3}[0-9X]$", x),
    doi = x == tolower(x) & startsWith(x, "10."),
    country_code = grepl("^[A-Z]{2}$", x),
    cc_license = x %in% cc_licenses,
    oa_model = x %in% c("hybrid", "full_oa"),
    oa_status = x %in% c("diamond", "gold", "hybrid", "bronze", "green", "closed"),
    work_type = grepl("^[a-z][a-z-]*$", x),
    openalex_source_id = ,
    openalex_id = startsWith(x, "https://openalex.org/"),
    ror = ,
    ror_author = ,
    ror_agreement = startsWith(x, "https://ror.org/"),
    author_role = x %in% c("corresponding", "first"),
    match_type = x %in% c("direct", "child", "parent", "related"),
    rep(TRUE, length(x))
  )
  x[!ok]
}

# Roxygen `@format` section generated from the schema
#
# Used inline in `R/data.R`, so the package docs always match
# `inst/schema/columns.csv`.
rd_format <- function(table) {
  schema <- jn_schema(table)
  items <- sprintf(
    "- `%s` (%s%s): %s",
    schema$column,
    schema$type,
    ifelse(schema$key, ", key", ""),
    schema$description
  )
  paste0(
    "A tibble with ", nrow(schema), " columns:\n\n",
    paste(items, collapse = "\n")
  )
}

# One-line description of each table's rows, from inst/schema/tables.csv
table_grains <- function() {
  path <- system.file("schema", "tables.csv", package = "jnanalytics", mustWork = TRUE)
  tibble::as_tibble(utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8"))
}
