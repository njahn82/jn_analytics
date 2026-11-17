#' Journals
#'
#' One row per journal covered by a transformative agreement in the cOAlition S
#' Journal Checker Tool (JCT).
#'
#' `oa_model` distinguishes hybrid from fully open access journals. Journals
#' in the curated list `data-raw/manual/oa_model.csv` keep its value; the
#' others are `full_oa` if OpenAlex marks the journal as open access or in
#' DOAJ, and `hybrid` otherwise. Title, OpenAlex ID and `oa_flip_year` come
#' from OpenAlex. `publisher` is the most frequent normalised publisher among
#' the agreements that cover the journal.
#'
#' @format `r rd_format("journals")`
#' @source cOAlition S Journal Checker Tool, ESAC Transformative Agreement
#'   Registry, OpenAlex.
#' @family reference tables
"journals"

#' Journal ISSNs
#'
#' One row per ISSN, linking print, electronic and linking ISSNs to the
#' journal's `issn_l`. Use it to match ISSNs from other sources to
#' [journals].
#'
#' @format `r rd_format("journal_issns")`
#' @family reference tables
"journal_issns"

#' Transformative agreements
#'
#' One row per transformative agreement listed in the Journal Checker Tool,
#' identified by its ESAC ID. `country` is only set for national agreements.
#' Agreements missing from the ESAC registry get an inferred period, flagged
#' by `is_period_inferred`.
#'
#' @format `r rd_format("agreements")`
#' @source ESAC Transformative Agreement Registry
#'   (<https://esac-initiative.org/about/transformative-agreements/agreement-registry/>).
#' @family reference tables
"agreements"

#' Journals covered by transformative agreements
#'
#' Which journals each agreement covers. A journal covered by several
#' agreements appears once per agreement.
#'
#' @format `r rd_format("agreement_journals")`
#' @family reference tables
"agreement_journals"

#' Institutions participating in transformative agreements
#'
#' One row per agreement and participating institution, as listed in the
#' Journal Checker Tool, identified by ROR ID. In BigQuery, `article_agreements`
#' matches authors' institutions to these, including their child and parent
#' institutions.
#' Institutions listed without a valid ROR ID are not included.
#'
#' @format `r rd_format("agreement_institutions")`
#' @source cOAlition S Journal Checker Tool.
#' @family reference tables
"agreement_institutions"

#' Dashboard portfolios
#'
#' The publisher pages of the dashboard, one row per page and agreement. A
#' portfolio is the set of transformative agreements of one publisher, so
#' `agreement_id` gives the ESAC IDs of a page. Its journals are those of its
#' agreements in [agreement_journals].
#'
#' @format `r rd_format("portfolios")`
#' @family reference tables
"portfolios"
