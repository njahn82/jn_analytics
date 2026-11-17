-- OpenAlex journals with all their ISSNs, one row per source and ISSN.
-- Used to map JCT ISSNs to ISSN-Ls and to classify journals as hybrid or
-- fully open access. The result is filtered to JCT journals in R.
SELECT
  s.id AS openalex_source_id,
  s.issn_l,
  issn,
  s.display_name AS title,
  s.host_organization_name AS host_organization,
  s.type AS source_type,
  s.is_oa,
  s.is_in_doaj,
  s.oa_flip_year,
  s.works_count
FROM `{{openalex}}.sources` AS s,
  UNNEST(s.issn) AS issn
WHERE s.issn_l IS NOT NULL
