-- agreement_journal_year: works covered per agreement, journal, year, work
-- type and author role. `direct`, `child` and `parent` matches count, so an
-- agreement covers the institutions above and below a participating one;
-- `related` matches do not. A work under several agreements counts in each;
-- author roles overlap.
-- `articles_oa`: every work in a fully OA journal-year is OA; in a hybrid
-- journal-year, a work is OA with a CC licence in Crossref.
WITH covered AS (
  SELECT DISTINCT doi, agreement_id, author_role
  FROM `{{dataset}}.article_agreements`
  WHERE match_type IN ('direct', 'child', 'parent')
),

works AS (
  SELECT
    a.*,
    CASE
      WHEN j.oa_model = 'full_oa' AND j.oa_flip_year IS NOT NULL AND a.pub_year <= j.oa_flip_year
        THEN 'hybrid'
      ELSE j.oa_model
    END AS oa_model
  FROM `{{dataset}}.articles` AS a
  LEFT JOIN `{{dataset}}.journals` AS j
    ON j.issn_l = a.issn_l
)

SELECT
  c.agreement_id,
  w.issn_l,
  w.pub_year,
  w.oa_model,
  w.work_type,
  c.author_role,
  COUNT(*) AS articles,
  COUNTIF(w.oa_model = 'full_oa' OR w.is_oa_crossref) AS articles_oa,
  COUNTIF(w.oa_status IN ('diamond', 'gold', 'hybrid')) AS articles_oa_openalex,
  COUNTIF(w.is_oa_crossref) AS articles_with_cc_license
FROM covered AS c
INNER JOIN works AS w
  USING (doi)
GROUP BY c.agreement_id, w.issn_l, w.pub_year, w.oa_model, w.work_type, c.author_role
