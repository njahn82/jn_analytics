-- article_agreements: works covered by a transformative agreement through
-- the institution of their corresponding or first author.
--
-- A work matches an agreement if its journal is in the agreement, it was
-- published within the agreement period (OpenAlex publication date only;
-- Crossref `issued` is deliberately not used), and the
-- author's OpenAlex institution relates to a participating institution:
-- `direct` (same), `child` (part of it, any depth), `parent` (contains it) or
-- `related`. A parent is an umbrella organisation (e.g. CSIC, Chinese
-- Academy of Sciences) only if the agreement lists at least two institutions
-- whose only parent it is; otherwise the match is `parent_single`. This
-- excludes the shareholders that OpenAlex lists as parents of European XFEL
-- and universities that run joint institutes with CSIC.
-- `direct`, `child` and `parent` count in the aggregates.
WITH listed AS (
  SELECT
    ai.agreement_id,
    ai.ror AS ror_agreement,
    i.id AS inst_id,
    i.lineage,
    i.associated_institutions,
    (
      SELECT COUNT(*)
      FROM UNNEST(i.associated_institutions) AS a
      WHERE LOWER(a.relationship) = 'parent'
    ) AS n_parents
  FROM `{{dataset}}.agreement_institutions` AS ai
  INNER JOIN `{{openalex}}.institutions` AS i
    ON LOWER(i.ror) = ai.ror
),

-- Per agreement and parent organisation: how many listed institutions it
-- contains that have no other parent (joint institutes do not count)
parent_cover AS (
  SELECT
    agreement_id,
    ancestor AS parent_id,
    COUNT(DISTINCT IF(n_parents = 1, inst_id, NULL)) AS listed_children
  FROM listed
  CROSS JOIN UNNEST(lineage) AS ancestor
  WHERE ancestor != inst_id
  GROUP BY agreement_id, parent_id
),

-- OpenAlex institutions that match each participating institution
descendants AS (
  SELECT ancestor AS inst_id, i.id AS match_id
  FROM `{{openalex}}.institutions` AS i
  CROSS JOIN UNNEST(i.lineage) AS ancestor
  WHERE ancestor != i.id
),

expanded AS (
  SELECT agreement_id, ror_agreement, inst_id AS match_id, 'direct' AS match_type, 1 AS priority
  FROM listed
  UNION ALL
  SELECT l.agreement_id, l.ror_agreement, d.match_id, 'child', 2
  FROM listed AS l
  INNER JOIN descendants AS d
    ON d.inst_id = l.inst_id
  UNION ALL
  SELECT
    l.agreement_id, l.ror_agreement, ancestor,
    IF(pc.listed_children >= 2, 'parent', 'parent_single'),
    IF(pc.listed_children >= 2, 3, 4)
  FROM listed AS l
  CROSS JOIN UNNEST(l.lineage) AS ancestor
  INNER JOIN parent_cover AS pc
    ON pc.agreement_id = l.agreement_id
    AND pc.parent_id = ancestor
  WHERE ancestor != l.inst_id
  UNION ALL
  SELECT l.agreement_id, l.ror_agreement, a.id, 'related', 5
  FROM listed AS l
  CROSS JOIN UNNEST(l.associated_institutions) AS a
  WHERE LOWER(a.relationship) = 'related'
),

periods AS (
  SELECT agreement_id, start_date, end_date
  FROM `{{dataset}}.agreements`
  WHERE start_date IS NOT NULL AND end_date IS NOT NULL
),

authors AS (
  SELECT
    a.doi,
    a.pub_year,
    a.issn_l,
    SAFE_CAST(w.publication_date AS DATE) AS pub_date,
    author_role,
    i.id AS inst_id,
    LOWER(i.ror) AS ror_author
  FROM `{{dataset}}.articles` AS a
  INNER JOIN `{{openalex}}.works` AS w
    ON w.id = a.openalex_id
  CROSS JOIN UNNEST(w.authorships) AS au
  CROSS JOIN UNNEST(au.institutions) AS i
  CROSS JOIN UNNEST(ARRAY_CONCAT(
    IF(au.author_position = 'first', ['first'], CAST([] AS ARRAY<STRING>)),
    IF(COALESCE(au.is_corresponding, FALSE), ['corresponding'], CAST([] AS ARRAY<STRING>))
  )) AS author_role
  WHERE
    w.publication_year BETWEEN {{year_min}} AND {{year_max}}
    AND i.ror IS NOT NULL
)

SELECT
  au.doi,
  au.pub_year,
  aj.agreement_id,
  au.author_role,
  au.ror_author,
  e.ror_agreement,
  e.match_type
FROM authors AS au
INNER JOIN `{{dataset}}.agreement_journals` AS aj
  ON aj.issn_l = au.issn_l
INNER JOIN periods AS p
  ON p.agreement_id = aj.agreement_id
INNER JOIN expanded AS e
  ON e.agreement_id = aj.agreement_id
  AND e.match_id = au.inst_id
WHERE au.pub_date BETWEEN p.start_date AND p.end_date
-- One row per work, agreement, role and institution pair; the closest
-- relationship wins
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY au.doi, aj.agreement_id, au.author_role, au.ror_author, e.ror_agreement
  ORDER BY e.priority
) = 1
