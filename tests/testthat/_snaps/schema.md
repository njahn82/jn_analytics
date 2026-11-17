# jn_validate() reports column, type, format and key problems

    Code
      jn_validate(bad, "journal_issns")
    Condition
      Error in `jn_validate()`:
      ! Table "journal_issns" does not match the jnanalytics schema.
      x `issn` has 1 value(s) in a non-canonical form, e.g. '0021-843x'.
      x `issn_l` must be string, not integer.
      x Key `issn` has 1 missing value(s).
      x Key (issn) has 1 duplicated row(s).

---

    Code
      jn_validate(bad["issn"], "journal_issns")
    Condition
      Error in `jn_validate()`:
      ! Table "journal_issns" does not match the jnanalytics schema.
      x Columns must be `issn`, `issn_l`, not `issn`.
      x `issn` has 1 value(s) in a non-canonical form, e.g. '0021-843x'.
      x Key `issn` has 1 missing value(s).
      x Key (issn) has 1 duplicated row(s).

# jn_validate() checks controlled vocabularies

    Code
      jn_validate(journals, "journals")
    Condition
      Error in `jn_validate()`:
      ! Table "journals" does not match the jnanalytics schema.
      x `oa_model` has 1 value(s) in a non-canonical form, e.g. 'diamond'.

# jn_schema() rejects unknown tables

    Code
      jn_schema("jn_ind")
    Condition
      Error in `check_table_name()`:
      ! `table` must be one of the jnanalytics tables.
      i Available: "journals", "journal_issns", "agreements", "agreement_journals", "agreement_institutions", "portfolios", "articles", "article_first_authors", "article_agreements", "journal_year", "journal_year_country", "journal_year_country_license", "agreement_journal_year", "journal_year_license", and "release"

