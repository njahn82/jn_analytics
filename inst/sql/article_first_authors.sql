-- article_first_authors: one row per work, first-author institution and
-- country, from OpenAlex authorships.
--
-- `institution` rows come from matched OpenAlex institutions (with ROR).
-- `affiliation` rows add countries that OpenAlex derived from the
-- affiliation string but could not tie to an institution.
WITH first_authors AS (
  SELECT
    a.doi,
    a.pub_year,
    au.institutions,
    au.countries
  FROM `{{dataset}}.articles` AS a
  INNER JOIN `{{openalex}}.works` AS w
    ON w.id = a.openalex_id
  CROSS JOIN UNNEST(w.authorships) AS au
  WHERE
    w.publication_year BETWEEN {{year_min}} AND {{year_max}}
    AND au.author_position = 'first'
),

by_institution AS (
  SELECT DISTINCT
    fa.doi,
    fa.pub_year,
    i.ror,
    UPPER(i.country_code) AS country_code
  FROM first_authors AS fa
  CROSS JOIN UNNEST(fa.institutions) AS i
  WHERE i.country_code IS NOT NULL
),

by_affiliation AS (
  SELECT DISTINCT
    fa.doi,
    fa.pub_year,
    CAST(NULL AS STRING) AS ror,
    UPPER(c) AS country_code
  FROM first_authors AS fa
  CROSS JOIN UNNEST(fa.countries) AS c
  WHERE NOT EXISTS (
    SELECT 1 FROM by_institution AS bi
    WHERE bi.doi = fa.doi AND bi.country_code = UPPER(c)
  )
)

SELECT doi, pub_year, ror, country_code, 'institution' AS country_source
FROM by_institution
UNION ALL
SELECT doi, pub_year, ror, country_code, 'affiliation' AS country_source
FROM by_affiliation
