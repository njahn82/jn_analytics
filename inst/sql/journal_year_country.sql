-- journal_year_country: as journal_year, per first-author country.
-- Full counting: a work with first-author affiliations in two countries
-- counts once in each, so take journal totals from journal_year.
-- `articles_oa`: every work in a fully OA journal-year is OA; in a hybrid
-- journal-year, a work is OA with a CC licence in Crossref.
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
  w.issn_l,
  w.pub_year,
  w.oa_model,
  w.work_type,
  f.country_code,
  COUNT(*) AS articles,
  COUNTIF(w.is_in_crossref) AS articles_in_crossref,
  COUNTIF(w.oa_model = 'full_oa' OR w.is_oa_crossref) AS articles_oa,
  COUNTIF(w.oa_status IN ('diamond', 'gold', 'hybrid')) AS articles_oa_openalex,
  COUNTIF(w.is_oa_crossref) AS articles_with_cc_license,
  COUNTIF(w.has_tdm_link) AS articles_with_tdm_link,
  COUNTIF(w.has_orcid) AS articles_with_orcid,
  COUNTIF(w.has_affiliation) AS articles_with_affiliation,
  COUNTIF(w.has_affiliation_ror) AS articles_with_affiliation_ror,
  COUNTIF(w.has_funder) AS articles_with_funder,
  COUNTIF(w.has_funder_id) AS articles_with_funder_id,
  COUNTIF(w.has_abstract) AS articles_with_abstract,
  COUNTIF(w.has_references) AS articles_with_references
FROM works AS w
INNER JOIN (
  SELECT DISTINCT doi, country_code
  FROM `{{dataset}}.article_first_authors`
) AS f
  USING (doi)
GROUP BY w.issn_l, w.pub_year, w.oa_model, w.work_type, f.country_code
