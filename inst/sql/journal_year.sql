-- journal_year: works per journal, year and work type. Every count is a
-- number of works and can be summed over journals, years and work types.
-- `articles_oa`: every work in a fully OA journal-year is OA; in a hybrid
-- journal-year, a work is OA with a CC licence in Crossref.
-- `articles_with_cc_license` is the Crossref licence evidence alone.
WITH works AS (
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
  issn_l,
  pub_year,
  oa_model,
  work_type,
  COUNT(*) AS articles,
  COUNTIF(is_in_crossref) AS articles_in_crossref,
  COUNTIF(oa_model = 'full_oa' OR is_oa_crossref) AS articles_oa,
  COUNTIF(oa_status IN ('diamond', 'gold', 'hybrid')) AS articles_oa_openalex,
  COUNTIF(is_oa_crossref) AS articles_with_cc_license,
  COUNTIF(has_tdm_link) AS articles_with_tdm_link,
  COUNTIF(has_orcid) AS articles_with_orcid,
  COUNTIF(has_affiliation) AS articles_with_affiliation,
  COUNTIF(has_affiliation_ror) AS articles_with_affiliation_ror,
  COUNTIF(has_funder) AS articles_with_funder,
  COUNTIF(has_funder_id) AS articles_with_funder_id,
  COUNTIF(has_abstract) AS articles_with_abstract,
  COUNTIF(has_references) AS articles_with_references
FROM works
GROUP BY issn_l, pub_year, oa_model, work_type
