-- journal_year_country_license: works per journal, year, work type,
-- first-author country and CC licence. Full counting: a work with first-author
-- affiliations in two countries counts once in each.
SELECT
  a.issn_l,
  a.pub_year,
  CASE
    WHEN j.oa_model = 'full_oa' AND j.oa_flip_year IS NOT NULL AND a.pub_year <= j.oa_flip_year
      THEN 'hybrid'
    ELSE j.oa_model
  END AS oa_model,
  a.work_type,
  f.country_code,
  a.cc_license,
  COUNT(*) AS articles
FROM `{{dataset}}.articles` AS a
INNER JOIN (
  SELECT DISTINCT doi, country_code
  FROM `{{dataset}}.article_first_authors`
) AS f
  USING (doi)
LEFT JOIN `{{dataset}}.journals` AS j
  ON j.issn_l = a.issn_l
GROUP BY a.issn_l, a.pub_year, oa_model, a.work_type, f.country_code, a.cc_license
