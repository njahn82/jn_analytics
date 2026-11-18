-- agreement_institution_year: works eligible under an agreement per
-- participating institution, year, OA model, work type and author role,
-- summed from agreement_articles. A work whose author has several
-- participating institutions counts for each, so take agreement totals from
-- agreement_journal_year, never by summing over institutions.
SELECT
  agreement_id,
  ror,
  pub_year,
  oa_model,
  work_type,
  author_role,
  COUNT(*) AS articles,
  COUNTIF(is_oa) AS articles_oa,
  COUNTIF(oa_status IN ('diamond', 'gold', 'hybrid')) AS articles_oa_openalex,
  COUNTIF(cc_license IS NOT NULL) AS articles_with_cc_license
FROM `{{dataset}}.agreement_articles`
GROUP BY agreement_id, ror, pub_year, oa_model, work_type, author_role
