-- agreement_articles: works eligible under an agreement, one row per work,
-- agreement, institution and author role, with journal, year, work type and
-- OA status, for drill-downs (e.g. the dashboard) without joins. Counted
-- matches only (`direct`, `child`, `parent`), as in agreement_journal_year.
-- A work is attributed to its closest matches: to the participating
-- institutions it matches directly or through a child; only if it has no
-- such match, once to the umbrella organisation (the parent, e.g. the
-- Chinese Academy of Sciences) through which it is eligible. A work whose
-- author has several participating institutions has one row for each.
-- `is_oa`: every work in a fully OA journal-year is OA; in a hybrid
-- journal-year, a work is OA with a CC licence in Crossref.
WITH matches AS (
  SELECT
    doi,
    agreement_id,
    author_role,
    ror_agreement,
    ror_author,
    match_type,
    LOGICAL_OR(match_type IN ('direct', 'child'))
      OVER (PARTITION BY doi, agreement_id, author_role) AS has_close_match
  FROM `{{dataset}}.article_agreements`
  WHERE match_type IN ('direct', 'child', 'parent')
),

covered AS (
  SELECT
    doi,
    agreement_id,
    author_role,
    ror_agreement AS ror,
    IF(LOGICAL_OR(match_type = 'direct'), 'direct', 'child') AS match_type
  FROM matches
  WHERE has_close_match AND match_type IN ('direct', 'child')
  GROUP BY doi, agreement_id, author_role, ror_agreement
  UNION ALL
  SELECT DISTINCT
    doi,
    agreement_id,
    author_role,
    ror_author AS ror,
    'parent' AS match_type
  FROM matches
  WHERE NOT has_close_match
),

works AS (
  SELECT
    a.doi,
    a.issn_l,
    a.pub_year,
    a.work_type,
    a.is_oa_crossref,
    a.cc_license,
    a.oa_status,
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
  c.ror,
  c.match_type,
  c.doi,
  c.author_role,
  w.pub_year,
  w.issn_l,
  w.oa_model,
  w.work_type,
  COALESCE(w.oa_model = 'full_oa', FALSE) OR w.is_oa_crossref AS is_oa,
  w.cc_license,
  w.oa_status
FROM covered AS c
INNER JOIN works AS w
  USING (doi)
