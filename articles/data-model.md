# Data model

jnanalytics describes the journal market in transformative agreements as
one set of tidy tables. Reference tables describe journals and
agreements once; article tables hold the facts; aggregates are built
from them for the dashboard and quick analyses. All tables are built in
Google BigQuery, in `subugoe-collaborative.jn_analytics`, from Crossref
(`cr_instant`) and OpenAlex (`openalex_walden`), using the journal and
institution lists of the cOAlition S Journal Checker Tool (JCT) and the
ESAC registry. All tables are also published as Parquet files in the
Hugging Face dataset
[`najkoja/jn_analytics`](https://huggingface.co/datasets/najkoja/jn_analytics),
one tagged version per release, with the article tables split by
publication year; the column descriptions are stored in the Parquet
metadata.

## Tables

| Table | Grain | Available in |
|:---|:---|:---|
| [`journals`](#journals) | one row per journal in a transformative agreement | package, Hugging Face, BigQuery |
| [`journal_issns`](#journal-issns) | one row per ISSN | package, Hugging Face, BigQuery |
| [`agreements`](#agreements) | one row per transformative agreement | package, Hugging Face, BigQuery |
| [`agreement_journals`](#agreement-journals) | one row per agreement and journal | package, Hugging Face, BigQuery |
| [`agreement_institutions`](#agreement-institutions) | one row per agreement and participating institution | package, Hugging Face, BigQuery |
| [`portfolios`](#portfolios) | one row per dashboard page and agreement (ESAC ID); journals via agreement_journals | package, Hugging Face, BigQuery |
| [`articles`](#articles) | one row per work with a DOI | Hugging Face, BigQuery |
| [`article_first_authors`](#article-first-authors) | one row per work, first-author institution and country | Hugging Face, BigQuery |
| [`article_agreements`](#article-agreements) | one row per work, agreement, author role and institution match | Hugging Face, BigQuery |
| [`agreement_articles`](#agreement-articles) | one row per eligible work, agreement, participating institution and author role, with journal and OA status | Hugging Face, BigQuery |
| [`journal_year`](#journal-year) | works per journal, year and work type | Hugging Face, BigQuery |
| [`journal_year_country`](#journal-year-country) | as journal_year, per first-author country | Hugging Face, BigQuery |
| [`journal_year_license`](#journal-year-license) | works per journal, year, work type and CC licence | Hugging Face, BigQuery |
| [`journal_year_country_license`](#journal-year-country-license) | works per journal, year, work type, first-author country and CC licence | Hugging Face, BigQuery |
| [`agreement_journal_year`](#agreement-journal-year) | works covered per agreement, journal, year, work type and author role | Hugging Face, BigQuery |
| [`agreement_institution_year`](#agreement-institution-year) | works eligible per agreement, participating institution, year, OA model, work type and author role | Hugging Face, BigQuery |
| [`release`](#release) | one row describing the release | Hugging Face, BigQuery |

## Counting rules

- **Works.** All works with a DOI whose primary location is a journal in
  `journals`, published from 2016, of any OpenAlex type. Nothing is
  excluded in SQL. Filter on `work_type`; research articles are
  `article` and `review`.
- **Publication year.** OpenAlex `publication_year`. The Crossref year
  is kept in `articles.pub_year_crossref` for comparison; Crossref is
  matched by DOI only, never by date.
- **Open access.** Every work in a fully OA journal-year is OA. In a
  hybrid journal-year, a work is OA if Crossref has a Creative Commons
  licence for its version of record, whatever its start date, as in
  hoaddata 0.3 (CC BY-NC-SA in four delayed-OA journals does not count).
  `articles_oa` counts both. `articles_with_cc_license` counts the
  Crossref licence evidence alone; in fully OA journals it is a metadata
  indicator, not OA evidence. `articles_oa_openalex` counts works
  OpenAlex considers open at the publisher (`diamond`, `gold` or
  `hybrid`).
- **Hybrid or fully OA.** `journals.oa_model` is the current status from
  OpenAlex (`is_oa` or DOAJ) or the curated list. The aggregates carry
  an `oa_model` per year: a journal counts as hybrid up to and including
  its OpenAlex `oa_flip_year`, a transition year, and as fully OA
  afterwards. Publishers that turned all their journals fully OA at once
  are listed in `data-raw/manual/oa_flips.csv` (for example ACM from
  2026); their hybrid journals count as hybrid up to the year before and
  fully OA from then on.
- **Countries.** First-author countries from OpenAlex, with full
  counting: a work with first-author affiliations in two countries
  counts in both. Take journal totals from `journal_year`, never by
  summing over countries.
- **Agreements.** A work is covered by an agreement if its journal is in
  the agreement, its OpenAlex publication date lies within the agreement
  period, and its first author’s OpenAlex institution is a participating
  institution, one of its children or its parent (`direct`, `child`,
  `parent`). A parent counts only if the agreement lists at least two
  institutions whose only parent it is, as for an author who gives only
  “CSIC” or “Chinese Academy of Sciences”; otherwise the match is
  `parent_single` and does not count. This leaves out the shareholders
  that OpenAlex lists as parents of European XFEL (among them CNRS and
  INFN) and universities that run joint institutes with CSIC, whose
  authors are not covered by CSIC’s agreements. `parent_single` and
  `related` matches are kept in `article_agreements` but not counted.
  `agreement_articles` lists the counted works per participating
  institution, and `agreement_institution_year` sums them; a work whose
  first author has two participating institutions counts for both, so
  take agreement totals from `agreement_journal_year`. Agreements
  missing from ESAC get an inferred period
  (`agreements.is_period_inferred`). Participating institutions come
  from the JCT; where it is wrong, a curated correction with its source
  adds or removes institutions
  (`data-raw/manual/institution_corrections.csv`, for example
  `ieee2025cas`).
- **Journals of an agreement.** Journal-level statistics per agreement
  (`jn_oa(by = "agreement_id")`) count all works in the journals an
  agreement covers, by default only in the years it ran. A journal in
  several agreements counts in each, so never sum over agreements. This
  is different from the works covered through authors’ institutions
  above.
- **Additivity.** Every count in an aggregate can be summed over
  journals, years and work types. Shares are not stored; compute them,
  for example `articles_oa / articles` or, for Crossref metadata,
  `articles_with_orcid / articles_in_crossref`.

## Differences from hoaddata 0.3

jnanalytics succeeds hoaddata 0.3, which remains available unchanged.
Agreement coverage is counted differently, so the numbers are not
directly comparable:

|  | hoaddata 0.3 | jnanalytics |
|----|----|----|
| Author | First author’s OpenAlex institutions | Same |
| Participating institution itself | Counts | Counts (`direct`) |
| Institutions below it | Direct children only | Any depth, from the OpenAlex `lineage` (`child`) |
| Institutions above it | Every direct parent | Only if the agreement lists at least two institutions whose only parent it is (`parent`); otherwise stored as `parent_single` and not counted |
| Related institutions | Count | Stored as `related`, not counted |
| Participant lists | JCT | JCT, with curated corrections (`data-raw/manual/institution_corrections.csv`) |
| Agreement period checked with | Crossref `issued` | OpenAlex publication date |
| Journals | Hybrid journals | Hybrid and fully OA journals |

hoaddata 0.3 took every institution OpenAlex lists as associated with a
participating one, whatever the relationship. Where OpenAlex lists many
parents, this made authors eligible who are not covered: European XFEL
has 14 parents in OpenAlex, its shareholders such as CNRS, INFN and CEA,
so their authors counted under every agreement listing European XFEL.
Likewise, universities that run joint institutes with CSIC made all
their authors eligible under CSIC’s agreements. jnanalytics therefore
counts fewer works through parents and related institutions, and more
through institutions further below a participating one.

## Columns

### journals

one row per journal in a transformative agreement. Available in:
package, Hugging Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `issn_l` | string, key | Linking ISSN |
| `title` | string | Journal title (OpenAlex, else the Journal Checker Tool) |
| `publisher` | string | Normalised publisher name, e.g. `Wiley` |
| `oa_model` | string | Current OA model: `hybrid` or `full_oa` (fully open access, according to OpenAlex, the curated list or a publisher-wide flip in `data-raw/manual/oa_flips.csv`); `NA` = not in OpenAlex. The aggregates carry a year-aware `oa_model` that uses `oa_flip_year` |
| `oa_flip_year` | integer | Year the journal became fully OA according to OpenAlex, or for a publisher-wide flip the year before it took effect; `NA` if unknown or never. This and earlier years count as hybrid in the aggregates |
| `openalex_source_id` | string | OpenAlex source ID |

### journal_issns

one row per ISSN. Available in: package, Hugging Face, BigQuery.

| Column   | Type        | Description                |
|:---------|:------------|:---------------------------|
| `issn`   | string, key | Any ISSN of the journal    |
| `issn_l` | string      | Linking ISSN it belongs to |

### agreements

one row per transformative agreement. Available in: package, Hugging
Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `agreement_id` | string, key | ESAC ID as used in the Journal Checker Tool |
| `agreement_name` | string | `publisher (lead_institution)`, e.g. `Wiley (DEAL)` |
| `publisher` | string | Same names as in `journals` |
| `country` | string | ISO-2 country of the consortium, if national |
| `lead_institution` | string | Consortium lead, e.g. `MPDL` |
| `start_date` | date | Start of the agreement according to ESAC, or inferred (see `is_period_inferred`) |
| `end_date` | date | End of the agreement according to ESAC, or inferred (see `is_period_inferred`) |
| `is_period_inferred` | boolean | `TRUE` if the agreement is missing from ESAC and its period is inferred: from 1 January of the year in its ID to the end of the year it was last listed in the Journal Checker Tool |

### agreement_journals

one row per agreement and journal. Available in: package, Hugging Face,
BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `agreement_id` | string, key | → `agreements` |
| `issn_l` | string, key | → `journals` |
| `last_seen` | date | Date the journal was last listed for this agreement in the Journal Checker Tool; `NA` if only listed in archived JCT data (hoaddata 0.3) |

### agreement_institutions

one row per agreement and participating institution. Available in:
package, Hugging Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `agreement_id` | string, key | → `agreements` |
| `ror` | string, key | ROR ID of a participating institution as listed in the Journal Checker Tool or added by a curated correction (`data-raw/manual/institution_corrections.csv`), full URL |
| `inst_name` | string | Institution name as listed in the Journal Checker Tool or in the curated correction |
| `last_seen` | date | Date the institution was last listed for this agreement in the Journal Checker Tool; `NA` if only listed in archived JCT data (hoaddata 0.3) or added by a curated correction |

### portfolios

one row per dashboard page and agreement (ESAC ID); journals via
agreement_journals. Available in: package, Hugging Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `portfolio_id` | string, key | Page slug, e.g. `wiley` |
| `portfolio_label` | string | Page title, e.g. `Wiley` |
| `agreement_id` | string, key | ESAC ID of an agreement on this page (→ `agreements`). The page’s journals are those of its agreements in `agreement_journals` |

### articles

one row per work with a DOI. Available in: Hugging Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `doi` | string, key | DOI, lowercase |
| `openalex_id` | string | OpenAlex work ID |
| `issn_l` | string | → `journals` |
| `pub_year` | integer | Publication year (OpenAlex `publication_year`), used for all counts |
| `pub_year_crossref` | integer | Year of Crossref `issued`, for comparison only; can differ from `pub_year`. `NA` if not in Crossref |
| `work_type` | string | OpenAlex work type, e.g. `article`, `review`, `editorial`, `letter` |
| `is_in_crossref` | boolean | DOI has a Crossref record; if `FALSE`, all Crossref-based columns are `FALSE` or `0` |
| `cc_license` | string | Normalised CC licence for the version of record from Crossref (most permissive if several); `NA` = no CC licence. CC BY-NC-SA in the delayed-OA journals 0021-9525, 0022-1007, 0022-1295 and 0270-6474 does not count |
| `is_oa_crossref` | boolean | CC licence for the version of record in Crossref, whatever its start date (`delay_in_days` is not used), as in hoaddata 0.3 |
| `oa_status` | string | OpenAlex OA status: `diamond`, `gold`, `hybrid`, `bronze`, `green` or `closed` |
| `has_tdm_link` | boolean | Full-text (TDM) link in Crossref |
| `has_orcid` | boolean | At least one author with ORCID in Crossref |
| `has_affiliation` | boolean | At least one author affiliation in Crossref |
| `has_affiliation_ror` | boolean | At least one author affiliation with a ROR ID in Crossref |
| `has_funder` | boolean | Funding metadata in Crossref |
| `has_funder_id` | boolean | At least one funder with a Funder Registry DOI in Crossref |
| `has_abstract` | boolean | Open abstract in Crossref |
| `has_references` | boolean | Open reference list in Crossref |
| `n_authors` | integer | Authors in Crossref |
| `n_authors_with_orcid` | integer | Authors with ORCID in Crossref |
| `n_affiliations` | integer | Author affiliations in Crossref, counted per author |
| `n_affiliations_with_ror` | integer | Author affiliations with a ROR ID in Crossref, counted per author |
| `n_funders` | integer | Funders in Crossref |
| `n_funders_with_id` | integer | Funders with a Funder Registry DOI in Crossref |

### article_first_authors

one row per work, first-author institution and country. Available in:
Hugging Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `doi` | string, key | → `articles` |
| `pub_year` | integer | Publication year of the work, as `articles.pub_year`; the files are split by it |
| `ror` | string, key | ROR ID of the institution, full URL; `NA` if OpenAlex found the country but no institution |
| `country_code` | string, key | ISO-2, uppercase |
| `country_source` | string | `institution` (country of a matched OpenAlex institution) or `affiliation` (country OpenAlex derived from the affiliation string only) |

### article_agreements

one row per work, agreement, author role and institution match.
Available in: Hugging Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `doi` | string, key | → `articles` |
| `pub_year` | integer | Publication year of the work, as `articles.pub_year`; the files are split by it |
| `agreement_id` | string, key | → `agreements`. The journal is covered by the agreement and the work’s OpenAlex publication date lies within the agreement period (Crossref `issued` is not used) |
| `author_role` | string, key | `corresponding` or `first`: the author whose institution matched. A first author who is also corresponding author gives one row per role |
| `ror_author` | string, key | ROR ID of the author’s institution (OpenAlex), full URL |
| `ror_agreement` | string, key | ROR ID of the participating institution it matched |
| `match_type` | string | How the author’s institution relates to the participating one, per OpenAlex: `direct` (same), `child` (part of it, any depth), `parent` (the author’s institution contains it, and the agreement lists at least two institutions whose only parent it is), `parent_single` (contains it, but without such evidence of an umbrella organisation, e.g. a shareholder of European XFEL or a university running a joint institute with CSIC) or `related`. `direct`, `child` and `parent` count in `agreement_journal_year`; `parent_single` and `related` are kept for comparison (hoaddata 0.3 counted `related` too) |

### agreement_articles

one row per eligible work, agreement, participating institution and
author role, with journal and OA status. Available in: Hugging Face,
BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `agreement_id` | string, key | → `agreements` |
| `ror` | string, key | Participating institution through which the work is eligible (`ror_agreement` in `article_agreements`), full URL; → `agreement_institutions` |
| `doi` | string, key | → `articles` |
| `author_role` | string, key | `first` or `corresponding`, as in `article_agreements`. Use `first` for agreement coverage; `corresponding` is sparse in OpenAlex |
| `pub_year` | integer | Publication year, as `articles.pub_year`; the files are split by it |
| `issn_l` | string | → `journals` |
| `oa_model` | string | OA model of the journal in that year: `hybrid` up to and including the OpenAlex `oa_flip_year` (a transition year), else as in `journals.oa_model`. Derived from `issn_l` and `pub_year`, not a key |
| `work_type` | string | OpenAlex work type, as in `articles` |
| `is_oa` | boolean | OA: every work in a fully OA journal-year; in a hybrid journal-year, a work with a CC licence in Crossref (as `articles_oa` in the aggregates) |
| `cc_license` | string | CC licence in Crossref, as in `articles` |
| `oa_status` | string | OpenAlex OA status, as in `articles` |

### journal_year

works per journal, year and work type. Available in: Hugging Face,
BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `issn_l` | string, key | → `journals` |
| `pub_year` | integer, key | Publication year |
| `oa_model` | string | OA model of the journal in that year: `hybrid` up to and including the OpenAlex `oa_flip_year` (a transition year), else as in `journals.oa_model`. Derived from `issn_l` and `pub_year`, not a key |
| `work_type` | string, key | OpenAlex work type, as in `articles`. Sum over all types for all works; filter to `article` and `review` for research articles |
| `articles` | integer | All works of this type |
| `articles_in_crossref` | integer | With a Crossref record; denominator for the Crossref-based columns |
| `articles_oa` | integer | OA: all works in a fully OA journal-year (`oa_model` `full_oa`); in a hybrid journal-year, works with a CC licence in Crossref (`is_oa_crossref`) |
| `articles_oa_openalex` | integer | OA at the publisher according to OpenAlex (`oa_status` `diamond`, `gold` or `hybrid`) |
| `articles_with_cc_license` | integer | With a CC licence for the version of record in Crossref (`is_oa_crossref`). In fully OA journals a metadata indicator, not OA evidence |
| `articles_with_tdm_link` | integer | With full-text links |
| `articles_with_orcid` | integer | With at least one ORCID |
| `articles_with_affiliation` | integer | With at least one author affiliation |
| `articles_with_affiliation_ror` | integer | With at least one ROR ID for an author affiliation |
| `articles_with_funder` | integer | With funding metadata |
| `articles_with_funder_id` | integer | With at least one Funder Registry DOI |
| `articles_with_abstract` | integer | With open abstract |
| `articles_with_references` | integer | With open reference list |

### journal_year_country

as journal_year, per first-author country. Available in: Hugging Face,
BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `issn_l` | string, key | → `journals` |
| `pub_year` | integer, key | Publication year |
| `oa_model` | string | OA model of the journal in that year: `hybrid` up to and including the OpenAlex `oa_flip_year` (a transition year), else as in `journals.oa_model`. Derived from `issn_l` and `pub_year`, not a key |
| `work_type` | string, key | OpenAlex work type, as in `articles`. Sum over all types for all works; filter to `article` and `review` for research articles |
| `country_code` | string, key | First author’s country. Full counting: a work with first-author affiliations in two countries counts in both, so summing over countries overstates totals; take journal totals from `journal_year` |
| `articles` | integer | All works of this type |
| `articles_in_crossref` | integer | With a Crossref record; denominator for the Crossref-based columns |
| `articles_oa` | integer | OA: all works in a fully OA journal-year (`oa_model` `full_oa`); in a hybrid journal-year, works with a CC licence in Crossref (`is_oa_crossref`) |
| `articles_oa_openalex` | integer | OA at the publisher according to OpenAlex (`oa_status` `diamond`, `gold` or `hybrid`) |
| `articles_with_cc_license` | integer | With a CC licence for the version of record in Crossref (`is_oa_crossref`). In fully OA journals a metadata indicator, not OA evidence |
| `articles_with_tdm_link` | integer | With full-text links |
| `articles_with_orcid` | integer | With at least one ORCID |
| `articles_with_affiliation` | integer | With at least one author affiliation |
| `articles_with_affiliation_ror` | integer | With at least one ROR ID for an author affiliation |
| `articles_with_funder` | integer | With funding metadata |
| `articles_with_funder_id` | integer | With at least one Funder Registry DOI |
| `articles_with_abstract` | integer | With open abstract |
| `articles_with_references` | integer | With open reference list |

### journal_year_license

works per journal, year, work type and CC licence. Available in: Hugging
Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `issn_l` | string, key | → `journals` |
| `pub_year` | integer, key | Publication year |
| `oa_model` | string | OA model of the journal in that year: `hybrid` up to and including the OpenAlex `oa_flip_year` (a transition year), else as in `journals.oa_model`. Derived from `issn_l` and `pub_year`, not a key |
| `work_type` | string, key | OpenAlex work type, as in `articles`. Sum over all types for all works; filter to `article` and `review` for research articles |
| `cc_license` | string, key | CC licence in Crossref; `NA` = none (in a fully OA journal the work is still OA) |
| `articles` | integer | Articles in this group |

### journal_year_country_license

works per journal, year, work type, first-author country and CC licence.
Available in: Hugging Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `issn_l` | string, key | → `journals` |
| `pub_year` | integer, key | Publication year |
| `oa_model` | string | OA model of the journal in that year: `hybrid` up to and including the OpenAlex `oa_flip_year` (a transition year), else as in `journals.oa_model`. Derived from `issn_l` and `pub_year`, not a key |
| `work_type` | string, key | OpenAlex work type, as in `articles`. Sum over all types for all works; filter to `article` and `review` for research articles |
| `country_code` | string, key | First author’s country. Full counting: a work with first-author affiliations in two countries counts in both, so summing over countries overstates totals; take journal totals from `journal_year` |
| `cc_license` | string, key | CC licence in Crossref; `NA` = none (in a fully OA journal the work is still OA) |
| `articles` | integer | Articles in this group |

### agreement_journal_year

works covered per agreement, journal, year, work type and author role.
Available in: Hugging Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `agreement_id` | string, key | → `agreements` |
| `issn_l` | string, key | → `journals` |
| `pub_year` | integer, key | Publication year |
| `oa_model` | string | OA model of the journal in that year: `hybrid` up to and including the OpenAlex `oa_flip_year` (a transition year), else as in `journals.oa_model`. Derived from `issn_l` and `pub_year`, not a key |
| `work_type` | string, key | OpenAlex work type, as in `articles` |
| `author_role` | string, key | `first` or `corresponding`, as in `article_agreements`. Use `first` for agreement coverage (as in hoaddata 0.3 and the dashboard); `corresponding` is kept for comparison. Roles overlap: never sum over them |
| `articles` | integer | Works covered by the agreement through a `direct`, `child` or `parent` match for this author role. A work under several agreements counts in each |
| `articles_oa` | integer | Of these, OA: all in a fully OA journal-year; in a hybrid journal-year, those with a CC licence in Crossref |
| `articles_oa_openalex` | integer | Of these, OA at the publisher according to OpenAlex |
| `articles_with_cc_license` | integer | Of these, with a CC licence in Crossref |

### agreement_institution_year

works eligible per agreement, participating institution, year, OA model,
work type and author role. Available in: Hugging Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `agreement_id` | string, key | → `agreements` |
| `ror` | string, key | Participating institution, full URL; → `agreement_institutions` for its name |
| `pub_year` | integer, key | Publication year |
| `oa_model` | string, key | OA model of the journal in that year: `hybrid` up to and including the OpenAlex `oa_flip_year` (a transition year), else as in `journals.oa_model`. Derived from `issn_l` and `pub_year`, not a key |
| `work_type` | string, key | OpenAlex work type, as in `articles` |
| `author_role` | string, key | `first` or `corresponding`, as in `article_agreements`. Use `first` for agreement coverage; `corresponding` is sparse in OpenAlex |
| `articles` | integer | Works eligible under the agreement through this participating institution (a `direct`, `child` or `parent` match). A work with several participating institutions counts for each, so never sum over institutions; take agreement totals from `agreement_journal_year` |
| `articles_oa` | integer | Of these, OA: all in a fully OA journal-year; in a hybrid journal-year, those with a CC licence in Crossref |
| `articles_oa_openalex` | integer | Of these, OA at the publisher according to OpenAlex |
| `articles_with_cc_license` | integer | Of these, with a CC licence in Crossref |

### release

one row describing the release. Available in: Hugging Face, BigQuery.

| Column | Type | Description |
|:---|:---|:---|
| `version` | string, key | Release version |
| `snapshot_date` | date | Date the release was built |
| `crossref_snapshot` | string | Crossref snapshot used |
| `openalex_snapshot` | string | OpenAlex snapshot used |
| `jct_snapshot` | string | Journal Checker Tool data used (last commit date) |
| `pub_year_min` | integer | First publication year covered |
| `pub_year_max` | integer | Last publication year covered |
