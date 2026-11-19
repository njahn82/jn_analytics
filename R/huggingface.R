#' Upload a release to Hugging Face
#'
#' Writes the dataset card (`README.md`) into `path`, uploads the folder
#' written by [jn_publish()] to the Hugging Face dataset repository in one
#' commit and tags that commit with the build date of the release
#' (`release$snapshot_date`, e.g. `2026-11-17`). Parquet files in the
#' repository that are not part of the upload are deleted in the same
#' commit; earlier releases stay available under their tags.
#'
#' Needs the Hugging Face CLI (`hf`) and a token with write access to `repo`,
#' from `hf auth login` or the `HF_TOKEN` environment variable. If the tag
#' exists already (a second build on the same day), it is moved to the new
#' commit.
#'
#' @param path Directory written by [jn_publish()], with `release.parquet`.
#' @param repo Hugging Face dataset repository.
#' @param tag Tag for the release. Defaults to its build date.
#'
#' @return The tag, invisibly.
#' @export
jn_upload_hf <- function(path = "parquet", repo = jn_hf_repo(), tag = NULL) {
  rlang::check_installed(c("arrow", "jsonlite"))
  release <- read_release(path)
  tag <- tag %||% format(release$snapshot_date)
  # The upload deletes remote Parquet files that are not uploaded, so a
  # partial export must not go up
  missing <- setdiff(c(jn_publish_tables(), "release"), export_files(path)$table)
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "{.path {path}} lacks table{?s} {.val {missing}}.",
      "i" = "Export all tables with {.fn jn_publish} first."
    ))
  }
  if (!nzchar(Sys.which("hf"))) {
    cli::cli_abort(c(
      "The Hugging Face CLI {.code hf} is not installed.",
      "i" = "Install it with {.code brew install hf} or {.code pipx install huggingface_hub}."
    ))
  }

  writeLines(dataset_card(path, repo), file.path(path, "README.md"), useBytes = TRUE)
  run_hf(c(
    "upload", repo, path, ".", "--repo-type", "dataset",
    "--commit-message", shQuote(paste("Release", tag)),
    "--delete", shQuote("*.parquet")
  ))

  tags <- run_hf(c("repos", "tag", "list", repo, "--repo-type", "dataset", "--format", "quiet"))
  if (tag %in% trimws(tags)) {
    cli::cli_inform("Tag {.val {tag}} exists; moving it to the new commit.")
    run_hf(c("repos", "tag", "delete", repo, tag, "--repo-type", "dataset", "--yes"))
  }
  run_hf(c(
    "repos", "tag", "create", repo, tag, "--repo-type", "dataset",
    "--message", shQuote(paste("jnanalytics", release$version, "built", tag))
  ))
  cli::cli_inform("Uploaded {.path {path}} to {.url {hf_url(repo)}}, tagged {.val {tag}}.")
  invisible(tag)
}

jn_hf_repo <- function() "najkoja/jn_analytics"

hf_url <- function(repo, file = NULL, revision = "main") {
  base <- paste0("https://huggingface.co/datasets/", repo)
  if (is.null(file)) base else paste0(base, "/resolve/", revision, "/", file)
}

run_hf <- function(args, call = rlang::caller_env()) {
  out <- suppressWarnings(system2("hf", args, stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status") %||% 0L
  if (status != 0) {
    command <- paste("hf", args[1], args[2])
    output <- utils::tail(out, 5)
    cli::cli_abort(
      c(
        "{.code {command}} failed.",
        rlang::set_names(sprintf("{output[%d]}", seq_along(output)), rep("x", length(output)))
      ),
      call = call
    )
  }
  out
}

read_release <- function(path) {
  file <- file.path(path, "release.parquet")
  if (!file.exists(file)) {
    cli::cli_abort(
      "{.file {file}} not found. Export with {.fn jn_publish} first.",
      call = rlang::caller_env()
    )
  }
  tibble::as_tibble(arrow::read_parquet(file))
}

# Tables in an export folder: <table>.parquet or <table>/<table>_<year>.parquet
export_files <- function(path) {
  files <- list.files(path, pattern = "\\.parquet$", recursive = TRUE)
  table <- ifelse(dirname(files) == ".", sub("\\.parquet$", "", files), dirname(files))
  tibble::tibble(table = table, file = files)
}

# Dataset card for Hugging Face: YAML header with one viewer config per
# table, then release, tables, usage, columns and licence
dataset_card <- function(path, repo = jn_hf_repo()) {
  release <- read_release(path)
  files <- export_files(path)
  grains <- table_grains()
  tables <- grains$table[grains$table %in% files$table]

  pattern <- vapply(tables, function(t) {
    f <- files$file[files$table == t]
    if (length(f) == 1 && f == paste0(t, ".parquet")) f else paste0(t, "/*.parquet")
  }, "")
  rows <- vapply(tables, function(t) {
    nrow(arrow::open_dataset(file.path(path, files$file[files$table == t])))
  }, numeric(1))
  size_mb <- vapply(tables, function(t) {
    sum(file.size(file.path(path, files$file[files$table == t]))) / 1e6
  }, numeric(1))

  yaml <- c(
    "---",
    "license: cc0-1.0",
    "pretty_name: \"jnanalytics: journals in transformative agreements\"",
    "language:", "- en",
    "tags:", "- open-access", "- scholarly-publishing", "- bibliometrics",
    "- transformative-agreements",
    "configs:",
    unlist(lapply(tables, function(t) {
      c(
        paste0("- config_name: ", t),
        paste0("  data_files: \"", pattern[[t]], "\""),
        if (t == "journal_year") "  default: true"
      )
    })),
    "---"
  )

  years <- paste(release$pub_year_min, release$pub_year_max, sep = "\u2013")
  site <- "https://njahn82.github.io/jn_analytics"
  md_table <- function(header, body) {
    c(
      paste0("| ", paste(header, collapse = " | "), " |"),
      paste0("|", paste(rep("---", length(header)), collapse = "|"), "|"),
      apply(body, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
    )
  }
  escape <- function(x) gsub("|", "\\|", x, fixed = TRUE)

  release_table <- md_table(
    c("", ""),
    cbind(
      c(
        "Package version", "Built", "Crossref snapshot", "OpenAlex snapshot",
        "JCT snapshot", "Publication years"
      ),
      c(
        release$version, format(release$snapshot_date), release$crossref_snapshot,
        release$openalex_snapshot, release$jct_snapshot, years
      )
    )
  )
  table_list <- md_table(
    c("Table", "Rows", "Size", "Files", "Grain"),
    cbind(
      paste0("`", tables, "`"),
      format(rows, big.mark = ",", scientific = FALSE, trim = TRUE),
      ifelse(size_mb < 0.1, "< 0.1 MB", sprintf("%.1f MB", size_mb)),
      paste0("`", pattern, "`"),
      escape(grains$grain[match(tables, grains$table)])
    )
  )
  columns <- unlist(lapply(tables, function(t) {
    schema <- jn_schema(t)
    c(
      "", paste0("<details><summary><code>", t, "</code></summary>"), "",
      md_table(
        c("Column", "Type", "Description"),
        cbind(
          paste0("`", schema$column, "`"),
          paste0(schema$type, ifelse(schema$key, ", key", "")),
          escape(schema$description)
        )
      ),
      "", "</details>"
    )
  }))

  unname(c(
    yaml,
    "",
    "# jnanalytics: journals in transformative agreements",
    "",
    "Open data about the journal market in transformative agreements, hybrid",
    "and fully open access journals. Built with the R package",
    paste0("[jnanalytics](https://github.com/njahn82/jn_analytics) from Crossref"),
    "and OpenAlex, using the journal and institution lists of the cOAlition S",
    "Journal Checker Tool (JCT) and the ESAC registry. Successor of hoaddata.",
    "",
    paste("## Release", format(release$snapshot_date)),
    "",
    release_table,
    "",
    "Each release is a tagged commit named after its build date. Read an",
    "earlier release with `revision=\"<date>\"` in Python, or",
    paste0("`", hf_url(repo, "<file>", "<date>"), "`."),
    "",
    "## Tables",
    "",
    table_list,
    "",
    "Article tables are split into one file per publication year (`pub_year`).",
    paste0(
      "Every table and column, and the counting rules, are described in the [data model](",
      site, "/articles/data-model.html). Two rules matter most:"
    ),
    "",
    "- Counts can be summed over journals, years and work types; compute shares",
    "  from the sums. Filter `work_type` to `article` and `review` for research",
    "  articles.",
    "- The country tables count a work once per first-author country (full",
    "  counting). Take totals from `journal_year`, never by summing over countries.",
    "",
    "## Usage",
    "",
    "DuckDB reads the files directly:",
    "",
    "```sql",
    "SELECT pub_year, oa_model,",
    "       sum(articles) AS articles,",
    "       sum(articles_oa) / sum(articles) AS share_oa",
    paste0("FROM 'hf://datasets/", repo, "/journal_year.parquet'"),
    "WHERE work_type IN ('article', 'review')",
    "GROUP BY ALL",
    "ORDER BY ALL;",
    "",
    "SELECT count(*)",
    paste0("FROM 'hf://datasets/", repo, "/articles/*.parquet'"),
    "WHERE pub_year = 2025;",
    "```",
    "",
    "Python, with pandas and huggingface_hub installed:",
    "",
    "```python",
    "import pandas as pd",
    "",
    paste0("journal_year = pd.read_parquet(\"hf://datasets/", repo, "/journal_year.parquet\")"),
    "```",
    "",
    "R, with [jnanalytics](https://github.com/njahn82/jn_analytics), which downloads",
    "the release into `my_data/` and updates it when a new one is out:",
    "",
    "```r",
    "library(jnanalytics)",
    "src <- jn_download()",
    "jn_oa(src, by = c(\"pub_year\", \"oa_model\"))",
    "```",
    "",
    "Each file carries its column descriptions as JSON in the Parquet metadata",
    "(`jn_columns`), with the table name (`jn_table`) and package version",
    "(`jn_version`).",
    "",
    "## Columns",
    columns,
    "",
    "## Licence",
    "",
    "CC0 1.0. OpenAlex data is CC0; the Crossref metadata used has no reuse",
    "restrictions (abstracts are not included, only whether one exists).",
    ""
  ))
}
