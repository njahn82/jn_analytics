-- journal_year_license: works per journal, year, work type and CC licence.
-- `cc_license` NULL = no CC licence; a group's total is the sum over all
-- licences including NULL, and equals `journal_year.articles`.
SELECT
  a.issn_l,
  a.pub_year,
  CASE
    WHEN j.oa_model = 'full_oa' AND j.oa_flip_year IS NOT NULL AND a.pub_year <= j.oa_flip_year
      THEN 'hybrid'
    ELSE j.oa_model
  END AS oa_model,
  a.work_type,
  a.cc_license,
  COUNT(*) AS articles
FROM `{{dataset}}.articles` AS a
LEFT JOIN `{{dataset}}.journals` AS j
  ON j.issn_l = a.issn_l
GROUP BY a.issn_l, a.pub_year, oa_model, a.work_type, a.cc_license
