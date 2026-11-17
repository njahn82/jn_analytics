-- articles: one row per work with a DOI in a journal of `journals`.
--
-- OpenAlex decides which works count, their journal, year and type.
-- Crossref, joined by DOI, provides the licence and the metadata indicators.
-- All works with a DOI are kept, whatever their type; paratext and other
-- non-research types are filtered downstream on `work_type`.
WITH jns AS (
  SELECT issn_l
  FROM `{{dataset}}.journals`
),

openalex AS (
  SELECT
    LOWER(REGEXP_REPLACE(w.doi, r'^https?://doi\.org/', '')) AS doi,
    w.id AS openalex_id,
    w.primary_location.source.issn_l AS issn_l,
    w.publication_year AS pub_year,
    w.type AS work_type,
    w.open_access.oa_status AS oa_status
  FROM `{{openalex}}.works` AS w
  INNER JOIN jns
    ON w.primary_location.source.issn_l = jns.issn_l
  WHERE
    w.publication_year BETWEEN {{year_min}} AND {{year_max}}
    AND w.doi IS NOT NULL
  -- A DOI can appear in more than one OpenAlex work
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY LOWER(REGEXP_REPLACE(w.doi, r'^https?://doi\.org/', ''))
    ORDER BY w.id
  ) = 1
),

crossref AS (
  SELECT
    LOWER(cr.doi) AS doi,
    EXTRACT(YEAR FROM cr.issued) AS pub_year_crossref,
    cr.license,
    EXISTS (
      SELECT 1 FROM UNNEST(cr.link) AS l
      WHERE l.intended_application = 'text-mining'
    ) AS has_tdm_link,
    cr.abstract IS NOT NULL AS has_abstract,
    -- `reference_count` instead of the `reference` array: Crossref has
    -- distributed all deposited references openly since 2022, for all records,
    -- so both give the same answer, but the array is about 80% of the bytes
    -- scanned
    COALESCE(cr.reference_count, 0) > 0 AS has_references,
    ARRAY_LENGTH(cr.author) AS n_authors,
    (
      SELECT COUNT(1) FROM UNNEST(cr.author) AS a
      WHERE a.orcid IS NOT NULL
    ) AS n_authors_with_orcid,
    -- Affiliations are counted per author: two authors at the same
    -- institution give two affiliations
    (
      SELECT COUNT(1) FROM UNNEST(cr.author) AS a, UNNEST(a.affiliation) AS af
    ) AS n_affiliations,
    (
      SELECT COUNT(1) FROM UNNEST(cr.author) AS a, UNNEST(a.affiliation) AS af
      WHERE EXISTS (
        SELECT 1 FROM UNNEST(af.id) AS i
        WHERE LOWER(i.id_type) = 'ror'
      )
    ) AS n_affiliations_with_ror,
    ARRAY_LENGTH(cr.funder) AS n_funders,
    (
      SELECT COUNT(1) FROM UNNEST(cr.funder) AS f
      WHERE f.doi IS NOT NULL
        OR EXISTS (
          SELECT 1 FROM UNNEST(f.id) AS i
          WHERE LOWER(i.id_type) = 'doi'
        )
    ) AS n_funders_with_id
  -- Matched by DOI only. Crossref `issued` and the OpenAlex publication year
  -- can differ by more than a year (online first, late issue assignment), so
  -- filtering Crossref by date would lose records.
  FROM `{{crossref}}.snapshot` AS cr
),

-- CC licence of the version of record, as in hoaddata 0.3. Licences for
-- accepted manuscripts do not count. `delay_in_days` is not used: it is the
-- gap between licence start and publication date, mostly a few days to weeks
-- for regular OA articles, not an embargo. If several licences apply, the
-- most permissive wins.
cc AS (
  SELECT
    doi,
    ARRAY_AGG(cc_license ORDER BY permissiveness LIMIT 1)[OFFSET(0)] AS cc_license
  FROM (
    SELECT
      crossref.doi,
      CASE REGEXP_REPLACE(
        REGEXP_EXTRACT(LOWER(lic.url), r'creativecommons\.org/licenses/(by[a-z-]*)'),
        r'-+$', ''
      )
        WHEN 'by' THEN 'CC BY'
        WHEN 'by-sa' THEN 'CC BY-SA'
        WHEN 'by-nc' THEN 'CC BY-NC'
        WHEN 'by-nc-sa' THEN 'CC BY-NC-SA'
        WHEN 'by-ncsa' THEN 'CC BY-NC-SA'
        WHEN 'by-nd' THEN 'CC BY-ND'
        WHEN 'by-nc-nd' THEN 'CC BY-NC-ND'
        WHEN 'by-ncnd' THEN 'CC BY-NC-ND'
      END AS cc_license
    FROM crossref,
      UNNEST(crossref.license) AS lic
    WHERE COALESCE(lic.content_version, '') != 'am'
  )
  LEFT JOIN UNNEST([
    STRUCT('CC BY' AS lic, 1 AS permissiveness),
    ('CC BY-SA', 2), ('CC BY-NC', 3), ('CC BY-NC-SA', 4),
    ('CC BY-ND', 5), ('CC BY-NC-ND', 6)
  ]) AS ord
    ON ord.lic = cc_license
  WHERE cc_license IS NOT NULL
  GROUP BY doi
)

SELECT
  openalex.doi,
  openalex.openalex_id,
  openalex.issn_l,
  openalex.pub_year,
  crossref.pub_year_crossref,
  openalex.work_type,
  crossref.doi IS NOT NULL AS is_in_crossref,
  oa_license.cc_license,
  oa_license.cc_license IS NOT NULL AS is_oa_crossref,
  openalex.oa_status,
  COALESCE(crossref.has_tdm_link, FALSE) AS has_tdm_link,
  COALESCE(crossref.n_authors_with_orcid, 0) > 0 AS has_orcid,
  COALESCE(crossref.n_affiliations, 0) > 0 AS has_affiliation,
  COALESCE(crossref.n_affiliations_with_ror, 0) > 0 AS has_affiliation_ror,
  COALESCE(crossref.n_funders, 0) > 0 AS has_funder,
  COALESCE(crossref.n_funders_with_id, 0) > 0 AS has_funder_id,
  COALESCE(crossref.has_abstract, FALSE) AS has_abstract,
  COALESCE(crossref.has_references, FALSE) AS has_references,
  COALESCE(crossref.n_authors, 0) AS n_authors,
  COALESCE(crossref.n_authors_with_orcid, 0) AS n_authors_with_orcid,
  COALESCE(crossref.n_affiliations, 0) AS n_affiliations,
  COALESCE(crossref.n_affiliations_with_ror, 0) AS n_affiliations_with_ror,
  COALESCE(crossref.n_funders, 0) AS n_funders,
  COALESCE(crossref.n_funders_with_id, 0) AS n_funders_with_id
FROM openalex
LEFT JOIN crossref
  ON openalex.doi = crossref.doi
LEFT JOIN cc
  ON openalex.doi = cc.doi
-- Delayed OA, as in hoaddata 0.3: these journals license their articles
-- CC BY-NC-SA only months after publication, so that licence does not count
CROSS JOIN UNNEST([STRUCT(
  CASE
    WHEN cc.cc_license = 'CC BY-NC-SA'
      AND openalex.issn_l IN ('0021-9525', '0022-1007', '0022-1295', '0270-6474')
      THEN NULL
    ELSE cc.cc_license
  END AS cc_license
)]) AS oa_license
