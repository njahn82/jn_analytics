# An export folder with every published table: empty files that follow the
# schema, articles split by year
local_export <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  empty <- function(table) {
    schema <- jn_schema(table)
    proto <- list(
      string = character(), integer = integer(),
      boolean = logical(), date = as.Date(character())
    )
    tibble::as_tibble(rlang::set_names(proto[schema$type], schema$column))
  }
  for (table in setdiff(jn_publish_tables(), jn_article_tables())) {
    write_jn_parquet(empty(table), table, file.path(dir, paste0(table, ".parquet")))
  }
  for (table in jn_article_tables()) {
    dir.create(file.path(dir, table))
    for (year in 2025:2026) {
      file <- file.path(dir, table, sprintf("%s_%d.parquet", table, year))
      write_jn_parquet(empty(table), table, file)
    }
  }
  release <- tibble::tibble(
    version = "0.2.0", snapshot_date = as.Date("2026-11-17"),
    crossref_snapshot = "2026-11-01", openalex_snapshot = "2026-10-30",
    jct_snapshot = "2026-11-09", pub_year_min = 2016L, pub_year_max = 2026L
  )
  write_jn_parquet(release, "release", file.path(dir, "release.parquet"))
  dir
}
