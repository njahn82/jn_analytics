# A fake Hugging Face repository with two releases. `hf_fetch()` writes as
# many bytes as the file list says, or fewer for files in `broken`
local_fake_hf <- function(releases = c("2026-11-18", "2026-08-01"),
                          broken = character(), offline = FALSE,
                          env = parent.frame()) {
  files <- data.frame(
    path = c(
      "README.md", "release.parquet", "journal_year.parquet",
      "agreement_articles/agreement_articles_2025.parquet",
      "articles/articles_2025.parquet"
    ),
    size = c(10, 20, 30, 40, 50)
  )
  fetched <- new.env()
  fetched$urls <- character()
  local_mocked_bindings(
    hf_releases = function(repo) {
      if (offline) stop("offline")
      data.frame(name = releases, commit = paste0("sha-", releases))
    },
    hf_release_files = function(repo, revision) files,
    hf_fetch = function(url, dest) {
      fetched$urls <- c(fetched$urls, url)
      path <- sub(".*/resolve/[^/]+/", "", url)
      n <- files$size[files$path == path] - (path %in% broken)
      writeBin(as.raw(rep(1, n)), dest)
    },
    .env = env
  )
  the$checked <- list()
  withr::defer(the$checked <- list(), envir = env)
  fetched
}

test_that("jn_download() fetches the latest release without article tables", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  fetched <- local_fake_hf()

  expect_message(src <- jn_download(dir), "Downloaded release")

  expect_s3_class(src, "jn_source")
  expect_setequal(src$tables, c("release", "journal_year", "agreement_articles"))
  expect_false(file.exists(file.path(dir, "articles")))
  expect_match(fetched$urls[1], "/resolve/sha-2026-11-18/", fixed = TRUE)
  state <- read_download_state(dir)
  expect_equal(state$release, "2026-11-18")
  expect_false(state$frozen)
})

test_that("jn_download() does nothing when the folder is up to date", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  fetched <- local_fake_hf()
  suppressMessages(jn_download(dir))
  n <- length(fetched$urls)

  expect_message(jn_download(dir), "up to date")
  expect_length(fetched$urls, n)
})

test_that("jn_download() updates to a newer release", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  local_fake_hf(releases = "2026-08-01")
  suppressMessages(jn_download(dir))
  local_fake_hf(releases = c("2026-11-18", "2026-08-01"))

  expect_message(jn_download(dir), "Downloaded release")
  expect_equal(read_download_state(dir)$release, "2026-11-18")
})

test_that("a frozen folder stays at its release until release = 'latest'", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  fetched <- local_fake_hf()
  suppressMessages(jn_download(dir, release = "2026-08-01"))
  expect_true(read_download_state(dir)$frozen)
  n <- length(fetched$urls)

  expect_message(jn_download(dir), "Frozen at")
  expect_length(fetched$urls, n)
  expect_equal(read_download_state(dir)$release, "2026-08-01")

  suppressMessages(jn_download(dir, release = "latest"))
  state <- read_download_state(dir)
  expect_equal(state$release, "2026-11-18")
  expect_false(state$frozen)
})

test_that("tables already in the folder stay in it", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  local_fake_hf(releases = "2026-08-01")
  suppressMessages(jn_download(dir, tables = "all"))
  local_fake_hf()

  src <- suppressMessages(jn_download(dir))
  expect_contains(src$tables, "articles")
  expect_true(file.exists(file.path(dir, "articles", "articles_2025.parquet")))
})

test_that("an incomplete download leaves the folder unchanged", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  local_fake_hf(releases = "2026-08-01")
  suppressMessages(jn_download(dir))
  local_fake_hf(broken = "journal_year.parquet")

  expect_snapshot(jn_download(dir), error = TRUE, transform = function(x) gsub(dir, "<dir>", x, fixed = TRUE))
  expect_equal(read_download_state(dir)$release, "2026-08-01")
  expect_equal(file.size(file.path(dir, "journal_year.parquet")), 30)
  expect_length(list.files(dir, all.files = TRUE, pattern = "^\\.download"), 0)
})

test_that("jn_download() works offline with data and stops without", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  local_fake_hf()
  suppressMessages(jn_download(dir))
  local_fake_hf(offline = TRUE)

  expect_warning(src <- jn_download(dir), "not reachable")
  expect_s3_class(src, "jn_source")
  hide_dir <- function(x) gsub("'[^']*'", "'<dir>'", x)
  expect_snapshot(jn_download(withr::local_tempdir()), error = TRUE, transform = hide_dir)
})

test_that("jn_download() explains unknown releases and tables", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  local_fake_hf()
  expect_snapshot(jn_download(withr::local_tempdir(), release = "2020-01-01"), error = TRUE)
  expect_snapshot(jn_download(withr::local_tempdir(), tables = "nope"), error = TRUE)
})

test_that("jn_source() tells once per session about a newer release", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  local_fake_hf(releases = "2026-08-01")
  suppressMessages(jn_download(dir))
  local_fake_hf()

  expect_message(jn_source(dir), "is available")
  expect_no_message(jn_source(dir))

  the$checked <- list()
  withr::local_options(jnanalytics.check_updates = FALSE)
  expect_no_message(jn_source(dir))
})
