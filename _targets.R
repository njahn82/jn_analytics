# The jnanalytics build pipeline. Run with targets::tar_make().
#
# Only steps whose inputs changed rerun:
# - raw JCT/ESAC files and curated lists -> reference tables
# - a SQL template                       -> that table and everything built on it
# - a new Crossref or OpenAlex snapshot  -> the BigQuery tables
# - a new calendar year                  -> the BigQuery tables
# - an exported file                     -> the upload to Hugging Face
# BigQuery tables are represented by a small fingerprint (rows, last change),
# so downstream steps rerun when an upstream table was rebuilt.
library(targets)

pkgload::load_all(quiet = TRUE)
tar_option_set(imports = "jnanalytics")
if (tar_active()) jn_bq_auth()

reference_tables <- c(
  "journals", "journal_issns", "agreements", "agreement_journals",
  "agreement_institutions", "portfolios"
)

# A BigQuery table built from inst/sql/<name>.sql. `deps` are the targets it
# reads from; they are referenced so targets sees the dependency.
bq_step <- function(name, deps) {
  tar_target_raw(
    paste0("bq_", name),
    substitute(
      {
        DEPS
        bq_fingerprint(jn_build_table(NAME, year_min = years$min, year_max = years$max))
      },
      list(DEPS = as.call(c(as.name("list"), lapply(deps, as.name))), NAME = name)
    )
  )
}

upload_step <- function(name) {
  tar_target_raw(
    paste0("upload_", name),
    substitute(
      {
        jn_upload_reference(reference[NAME])
        rlang::hash(reference[[NAME]])
      },
      list(NAME = name)
    )
  )
}

export_step <- function(name) {
  tar_target_raw(
    paste0("export_", name),
    substitute(
      {
        DEP
        jn_publish("parquet", tables = NAME)
      },
      list(DEP = as.name(paste0("bq_", name)), NAME = name)
    ),
    format = "file"
  )
}

bq_fingerprint <- function(tbl) {
  meta <- bigrquery::bq_table_meta(tbl)
  list(table = tbl$table, rows = meta$numRows, modified = meta$lastModifiedTime)
}

sql_file <- function(name) {
  tar_target_raw(
    paste0("sql_", name),
    file.path("inst", "sql", paste0(name, ".sql")),
    format = "file"
  )
}

bq_tables <- c(
  "articles", "article_first_authors", "journal_year", "journal_year_country",
  "journal_year_license", "journal_year_country_license", "article_agreements",
  "agreement_journal_year"
)

list(
  # Inputs that can change outside this repository: checked on every run,
  # downstream steps only rerun if the value changed
  tar_target(years, list(min = 2016L, max = as.integer(format(Sys.Date(), "%Y"))), cue = tar_cue("always")),
  tar_target(snapshots, jn_snapshots(), cue = tar_cue("always")),

  # Local inputs
  tar_target(
    raw_files,
    c(
      "data-raw/jct_jn_all.csv.gz", "data-raw/jct_inst_all.csv", "data-raw/esac_df.csv",
      list.files("data-raw/legacy", full.names = TRUE),
      list.files("data-raw/manual", full.names = TRUE)
    ),
    format = "file"
  ),
  lapply(c(bq_tables, "openalex_sources"), sql_file),

  # Reference tables
  tar_target(
    openalex_sources,
    {
      list(raw_files, sql_openalex_sources, snapshots$openalex)
      jn_fetch_openalex_sources("data-raw")
    },
    format = "file"
  ),
  tar_target(reference, {
    list(raw_files, openalex_sources)
    jn_update_reference("data-raw", quiet = TRUE)
  }),
  tar_target(bundled_data, jn_save_reference(reference, "data"), format = "file"),
  tar_target(
    diagnostics,
    {
      dir.create("data-raw/diagnostics", showWarnings = FALSE)
      files <- c("data-raw/diagnostics/unmatched_jct.csv", "data-raw/diagnostics/institutions_without_ror.csv")
      readr::write_csv(reference$diagnostics$unmatched_jct, files[1])
      readr::write_csv(reference$diagnostics$institutions_without_ror, files[2])
      files
    },
    format = "file"
  ),
  # One upload per reference table, returning a hash of its content, so a
  # change in one table only reruns the BigQuery steps that read it
  lapply(reference_tables, upload_step),
  # `articles` only reads the list of journals (`issn_l`), so it depends on
  # this hash rather than on the whole `journals` table: a change of OA model
  # or flip year reruns the aggregates, not the article tables
  tar_target(journal_ids, {
    upload_journals
    rlang::hash(sort(reference$journals$issn_l))
  }),

  # BigQuery tables, in dependency order
  bq_step("articles", c("sql_articles", "journal_ids", "snapshots")),
  bq_step("article_first_authors", c("sql_article_first_authors", "bq_articles", "snapshots")),
  bq_step("journal_year", c("sql_journal_year", "bq_articles", "upload_journals")),
  bq_step("journal_year_country", c("sql_journal_year_country", "bq_articles", "bq_article_first_authors", "upload_journals")),
  bq_step("journal_year_license", c("sql_journal_year_license", "bq_articles", "upload_journals")),
  bq_step("journal_year_country_license", c("sql_journal_year_country_license", "bq_articles", "bq_article_first_authors", "upload_journals")),
  bq_step("article_agreements", c(
    "sql_article_agreements", "bq_articles", "snapshots", "upload_agreements",
    "upload_agreement_journals", "upload_agreement_institutions"
  )),
  bq_step("agreement_journal_year", c("sql_agreement_journal_year", "bq_article_agreements", "bq_articles", "upload_journals")),

  # Parquet export into parquet/ (not in git), in the layout of the Hugging
  # Face dataset: one file per table, article tables split by year. One
  # target per article table, so a changed aggregate does not re-export them
  tar_target(
    export_tables,
    {
      list(
        upload_journals, upload_journal_issns, upload_agreements, upload_agreement_journals,
        upload_agreement_institutions, upload_portfolios, bq_journal_year,
        bq_journal_year_country, bq_journal_year_license,
        bq_journal_year_country_license, bq_agreement_journal_year
      )
      jn_publish("parquet", tables = setdiff(jn_publish_tables(), jn_article_tables()))
    },
    format = "file"
  ),
  export_step("articles"),
  export_step("article_first_authors"),
  export_step("article_agreements"),

  # Upload to Hugging Face, tagged with the build date; reruns only when an
  # exported file changed
  tar_target(hf_release, {
    list(export_tables, export_articles, export_article_first_authors, export_article_agreements)
    jn_upload_hf("parquet")
  })
)
