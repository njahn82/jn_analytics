#' Download the jnanalytics data
#'
#' Downloads a release of the jnanalytics tables from Hugging Face into a
#' folder, or updates the folder when a newer release exists, and returns the
#' folder as a source for the analysis functions. Nothing is downloaded when
#' the folder is up to date.
#'
#' The folder holds the Parquet files and `jn_release.json`, which records
#' the release, its commit, the tables and whether the folder is frozen. A
#' download goes to a temporary folder first and replaces the old files only
#' when it is complete, so an interrupted download leaves the data intact.
#'
#' @param dir Folder for the data, created if needed.
#' @param release `NULL` (default) for the latest release, or for the
#'   frozen release if the folder is frozen. A release tag such as
#'   `"2026-11-18"` downloads that release and freezes the folder: later
#'   calls do not update it. `"latest"` lifts the freeze.
#' @param tables `"default"` for all tables except the large article tables
#'   (`articles`, `article_first_authors`, `article_agreements`), `"all"`, or
#'   table names. Tables already in the folder are kept and updated too.
#' @param repo Hugging Face dataset repository.
#'
#' @return A `jn_source` for `dir`, see [jn_source()].
#' @export
#' @examples
#' \dontrun{
#' src <- jn_download()
#' jn_oa(src, by = c("pub_year", "oa_model"))
#'
#' # Freeze a project to one release
#' src <- jn_download(release = "2026-11-18")
#' }
jn_download <- function(dir = "my_data", release = NULL, tables = "default",
                        repo = jn_hf_repo()) {
  rlang::check_installed(c("arrow", "jsonlite"))
  call <- rlang::current_env()
  state <- read_download_state(dir)
  wanted <- unique(c(resolve_download_tables(tables, call), state$tables))

  refs <- tryCatch(hf_releases(repo), error = function(e) NULL)
  newest <- if (!is.null(refs)) refs$name[1]

  if (is.null(release) && isTRUE(state$frozen)) {
    target <- list(name = state$release, commit = state$commit, frozen = TRUE)
  } else {
    if (is.null(refs)) {
      if (!is.null(state)) {
        cli::cli_warn("Hugging Face not reachable; using release {.val {state$release}} in {.path {dir}}.")
        return(jn_source(dir))
      }
      cli::cli_abort(
        "Hugging Face not reachable, and {.path {dir}} has no jnanalytics data yet.",
        call = call
      )
    }
    name <- if (is.null(release) || identical(release, "latest")) newest else release
    if (!name %in% refs$name) {
      cli::cli_abort(c(
        "Release {.val {name}} not found.",
        "i" = "Available: {.val {refs$name}}"
      ), call = call)
    }
    target <- list(
      name = name, commit = refs$commit[refs$name == name],
      frozen = !is.null(release) && !identical(release, "latest")
    )
  }

  if (!is.null(state) && identical(state$commit, target$commit) && all(wanted %in% state$tables)) {
    if (!identical(isTRUE(state$frozen), target$frozen)) {
      state$frozen <- target$frozen
      write_download_state(dir, state)
    }
    cli::cli_inform("{.path {dir}} is up to date (release {.val {target$name}}).")
  } else {
    download_release(dir, repo, target, wanted, state, call)
  }
  if (target$frozen && !is.null(newest) && !identical(newest, target$name)) {
    cli::cli_inform(c("i" = "Frozen at {.val {target$name}}; release {.val {newest}} is available (use {.code release = \"latest\"})."))
  }
  the$checked[[normalizePath(dir)]] <- TRUE
  jn_source(dir)
}

# Package state: folders whose release was checked in this session
the <- new.env(parent = emptyenv())
the$checked <- list()

jn_article_download_skip <- function() {
  c("articles", "article_first_authors", "article_agreements")
}

resolve_download_tables <- function(tables, call) {
  all <- c(jn_publish_tables(), "release")
  if (identical(tables, "all")) {
    return(all)
  }
  if (identical(tables, "default")) {
    return(setdiff(all, jn_article_download_skip()))
  }
  unknown <- setdiff(tables, all)
  if (length(unknown) > 0) {
    cli::cli_abort(c(
      "Unknown table{?s}: {.val {unknown}}.",
      "i" = "Use {.val default}, {.val all} or names from {.fn jn_publish_tables}."
    ), call = call)
  }
  unique(c(tables, "release"))
}

download_release <- function(dir, repo, target, wanted, state, call) {
  files <- hf_release_files(repo, target$commit)
  files$table <- ifelse(
    dirname(files$path) == ".", sub("\\.parquet$", "", files$path), dirname(files$path)
  )
  files <- files[files$table %in% wanted | files$path == "README.md", c("path", "size")]

  tmp <- file.path(dir, paste0(".download-", target$name))
  unlink(tmp, recursive = TRUE)
  dir.create(tmp, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  old <- options(timeout = max(3600, getOption("timeout")))
  on.exit(options(old), add = TRUE)

  cli::cli_progress_bar(
    "Downloading release {target$name}", total = sum(files$size),
    format = "{cli::pb_spin} {cli::pb_name} {cli::pb_current_bytes}/{cli::pb_total_bytes}"
  )
  for (i in seq_len(nrow(files))) {
    dest <- file.path(tmp, files$path[i])
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    hf_fetch(hf_url(repo, files$path[i], target$commit), dest)
    if (!file.exists(dest) || file.size(dest) != files$size[i]) {
      cli::cli_abort(
        "Download of {.file {files$path[i]}} is incomplete; the folder was not changed.",
        call = call
      )
    }
    cli::cli_progress_update(inc = files$size[i])
  }
  cli::cli_progress_done()

  # Replace the files of the previous release, never other files in `dir`
  unlink(file.path(dir, unique(c(state$files$path, files$path))))
  for (path in files$path) {
    dir.create(dirname(file.path(dir, path)), recursive = TRUE, showWarnings = FALSE)
    file.rename(file.path(tmp, path), file.path(dir, path))
  }
  write_download_state(dir, list(
    repo = repo, release = target$name, commit = target$commit,
    frozen = target$frozen, downloaded = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    tables = wanted, files = files
  ))
  cli::cli_inform(
    "Downloaded release {.val {target$name}} to {.path {dir}} ({length(wanted)} tables, {round(sum(files$size) / 1e6)} MB)."
  )
}

download_state_file <- function(dir) file.path(dir, "jn_release.json")

read_download_state <- function(dir) {
  file <- download_state_file(dir)
  if (!file.exists(file)) {
    return(NULL)
  }
  state <- jsonlite::read_json(file, simplifyVector = TRUE)
  state$files <- as.data.frame(state$files)
  state
}

write_download_state <- function(dir, state) {
  jsonlite::write_json(state, download_state_file(dir), auto_unbox = TRUE, pretty = TRUE)
}

# Tell once per session if a downloaded folder is behind the latest release
check_download_update <- function(dir) {
  if (!isTRUE(getOption("jnanalytics.check_updates", TRUE))) {
    return(invisible())
  }
  key <- normalizePath(dir)
  state <- read_download_state(dir)
  if (is.null(state) || isTRUE(the$checked[[key]])) {
    return(invisible())
  }
  the$checked[[key]] <- TRUE
  refs <- tryCatch(hf_releases(state$repo), error = function(e) NULL)
  if (is.null(refs) || identical(refs$name[1], state$release)) {
    return(invisible())
  }
  if (isTRUE(state$frozen)) {
    cli::cli_inform(c("i" = "{.path {dir}} is frozen at release {.val {state$release}}; {.val {refs$name[1]}} is available."))
  } else {
    cli::cli_inform(c("i" = "Release {.val {refs$name[1]}} is available; update {.path {dir}} with {.code jn_download()}."))
  }
  invisible()
}

# Hugging Face API, in small functions so that tests can replace them

# Release tags, newest first, with their commits
hf_releases <- function(repo) {
  refs <- jsonlite::fromJSON(paste0("https://huggingface.co/api/datasets/", repo, "/refs"))
  tags <- refs$tags
  if (length(tags) == 0 || NROW(tags) == 0) {
    stop("No releases found.")
  }
  out <- data.frame(name = tags$name, commit = tags$targetCommit)
  out[order(out$name, decreasing = TRUE), , drop = FALSE]
}

# Files of a revision, with their sizes
hf_release_files <- function(repo, revision) {
  tree <- jsonlite::fromJSON(paste0(
    "https://huggingface.co/api/datasets/", repo, "/tree/", revision, "?recursive=true"
  ))
  tree <- tree[tree$type == "file" & grepl("\\.parquet$|^README\\.md$", tree$path), ]
  data.frame(path = tree$path, size = tree$size)
}

hf_fetch <- function(url, dest) {
  utils::download.file(url, dest, mode = "wb", quiet = TRUE)
}
