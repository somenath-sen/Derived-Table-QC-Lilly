# admci RWE Derived Tables — QC Query Set

Quality-control SQL for the five LLM-derived real-world-evidence (RWE) tables
delivered to schema `ad_mci_prod`. Each query is read-only and validates the
delivered tables against the Gold layer (`rgd_gold_ad`).

## Tables covered

| Domain | Delivered table |
|---|---|
| Biomarkers | `ad_mci_prod.admci_biomarkers` |
| Adverse events | `ad_mci_prod.admci_adverse_events` |
| ATT discontinuation | `ad_mci_prod.admci_att_discontinuation` |
| ARIA | `ad_mci_prod.admci_aria` |
| Scores | `ad_mci_prod.admci_scores` |

Reference schema: `rgd_gold_ad` (Gold `encounters`, `patients`, `medication`).

## File

- `admci_rwe_qc_queries.sql` — the full QC query set, organized into numbered
  sections. Each section is commented with what it checks and the expected result.

## What the queries check

| # | Check | Purpose / expected |
|---|---|---|
| 1 | Row & patient counts | Baseline size per table |
| 2 | Orphan ndid | Patients not in the Gold roster — expect 0 |
| 3 | Non-Gold encounterid | Encounter ids not in Gold encounters — expect 0 |
| 4 | enc_date = Gold | enc_date matches the Gold authoritative date — expect 0 off |
| 5 | Null encounterid | Retained-by-design rows without an encounter link |
| 6 | De-identification completeness | Evidence/reason columns populated |
| 7 | Duplicate assessment | Full-row duplicates on delivered columns |
| 8 | Event date vs enc_date | Direction split (BEFORE / SAME / AFTER / null) |
| 9 | Date plausibility | Future (> cutoff) or pre-2000 dates |
| 10 | enc_date range | Coverage span + cutoff held |
| 11 | Score value validity | Cognitive scores within the valid 0–30 range |
| 12 | Categorical value profiling | Flag/status/type columns free of junk values |
| 13 | Source-table caveats | Context on `rgd_gold_ad.medication` (not deliverable QC) |

## Notes / gotchas

- **Orphan and non-Gold checks use `LEFT JOIN ... IS NULL`, not `NOT IN`.**
  `NOT IN (subquery)` silently returns nothing when the subquery contains any
  NULL, which can mask real orphans. The LEFT JOIN / IS NULL form is
  authoritative.
- **Date column types differ.** `enc_date`, `test_date`, `result_date`,
  `aria_date`, and `score_date` are `DATE` (stored `YYYY-MM-DD`). In ATT,
  `enc_date` and `discontinuation_date` are `TEXT`; in adverse events,
  `event_onset_date` / `event_serious_date` are `TEXT`. Text date columns are
  parsed in-query (`STR_TO_DATE`), handling `MM-DD-YYYY` and mixed formats.
- **Biomarkers uses `encounterid`** (no underscore).
- **NULL encounterid / date fields denote unknown metadata, not "same event"** —
  duplicate checks treat rows with null keys as distinct.
- **Cutoff:** an encounter-date cutoff of 30 April 2026 was applied; ARIA is
  scoped to the Kisunla (donanemab) cohort with `aria_date >= 2023-06-11`.

## How to run

Run against the warehouse (MySQL) with read access to `ad_mci_prod` and
`rgd_gold_ad`. Sections are independent; run individually or as a full script.
