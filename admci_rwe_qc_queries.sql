-- =====================================================================
-- QC Query Set — admci RWE Derived Tables (schema: ad_mci_prod)
-- Tables: admci_biomarkers, admci_adverse_events,
--         admci_att_discontinuation, admci_aria, admci_scores
-- Reference schemas: rgd_gold_ad (Gold encounters + patients + medication)
-- =====================================================================


-- =====================================================================
-- 1. ROW & PATIENT COUNTS
-- =====================================================================
SELECT 'biomarkers' t, COUNT(*) rows_cnt, COUNT(DISTINCT CAST(ndid AS CHAR)) patients FROM ad_mci_prod.admci_biomarkers
UNION ALL SELECT 'adverse_events', COUNT(*), COUNT(DISTINCT CAST(ndid AS CHAR)) FROM ad_mci_prod.admci_adverse_events
UNION ALL SELECT 'att',            COUNT(*), COUNT(DISTINCT CAST(ndid AS CHAR)) FROM ad_mci_prod.admci_att_discontinuation
UNION ALL SELECT 'aria',           COUNT(*), COUNT(DISTINCT CAST(ndid AS CHAR)) FROM ad_mci_prod.admci_aria
UNION ALL SELECT 'scores',         COUNT(*), COUNT(DISTINCT CAST(ndid AS CHAR)) FROM ad_mci_prod.admci_scores;


-- =====================================================================
-- 2. ORPHAN ndid  (patient not in Gold roster)  -- expect 0
--    Uses LEFT JOIN / IS NULL (NOT the NOT IN anti-pattern, which
--    silently returns 0 when the subquery contains NULLs)
-- =====================================================================
SELECT 'biomarkers' t, COUNT(*) orphan_rows, COUNT(DISTINCT CAST(b.ndid AS CHAR)) orphan_patients
FROM ad_mci_prod.admci_biomarkers b
LEFT JOIN (SELECT DISTINCT ndid FROM rgd_gold_ad.patients) p ON b.ndid=p.ndid WHERE p.ndid IS NULL
UNION ALL SELECT 'adverse_events', COUNT(*), COUNT(DISTINCT CAST(a.ndid AS CHAR))
FROM ad_mci_prod.admci_adverse_events a
LEFT JOIN (SELECT DISTINCT ndid FROM rgd_gold_ad.patients) p ON a.ndid=p.ndid WHERE p.ndid IS NULL
UNION ALL SELECT 'att', COUNT(*), COUNT(DISTINCT CAST(a.ndid AS CHAR))
FROM ad_mci_prod.admci_att_discontinuation a
LEFT JOIN (SELECT DISTINCT CAST(ndid AS CHAR) ndid FROM rgd_gold_ad.patients) p ON CAST(a.ndid AS CHAR)=p.ndid WHERE p.ndid IS NULL
UNION ALL SELECT 'aria', COUNT(*), COUNT(DISTINCT CAST(a.ndid AS CHAR))
FROM ad_mci_prod.admci_aria a
LEFT JOIN (SELECT DISTINCT CAST(ndid AS CHAR) ndid FROM rgd_gold_ad.patients) p ON CAST(a.ndid AS CHAR)=p.ndid WHERE p.ndid IS NULL
UNION ALL SELECT 'scores', COUNT(*), COUNT(DISTINCT CAST(s.ndid AS CHAR))
FROM ad_mci_prod.admci_scores s
LEFT JOIN (SELECT DISTINCT ndid FROM rgd_gold_ad.patients) p ON s.ndid=p.ndid WHERE p.ndid IS NULL;


-- =====================================================================
-- 3. NON-GOLD encounterid  (encid not in Gold encounters)  -- expect 0
--    LEFT JOIN / IS NULL method
-- =====================================================================
SELECT 'biomarkers' t, COUNT(*) non_gold
FROM ad_mci_prod.admci_biomarkers b
LEFT JOIN rgd_gold_ad.encounters g ON b.encounterid=g.encounterid
WHERE b.encounterid IS NOT NULL AND g.encounterid IS NULL
UNION ALL SELECT 'adverse_events', COUNT(*)
FROM ad_mci_prod.admci_adverse_events a
LEFT JOIN rgd_gold_ad.encounters g ON a.encounterid=g.encounterid
WHERE a.encounterid IS NOT NULL AND g.encounterid IS NULL
UNION ALL SELECT 'att', COUNT(*)
FROM ad_mci_prod.admci_att_discontinuation a
LEFT JOIN rgd_gold_ad.encounters g ON CAST(a.encounterid AS CHAR)=CAST(g.encounterid AS CHAR)
WHERE a.encounterid IS NOT NULL AND g.encounterid IS NULL
UNION ALL SELECT 'aria', COUNT(*)
FROM ad_mci_prod.admci_aria a
LEFT JOIN rgd_gold_ad.encounters g ON CAST(a.encounterid AS CHAR)=CAST(g.encounterid AS CHAR)
WHERE a.encounterid IS NOT NULL AND g.encounterid IS NULL
UNION ALL SELECT 'scores', COUNT(*)
FROM ad_mci_prod.admci_scores s
LEFT JOIN rgd_gold_ad.encounters g ON s.encounterid=g.encounterid
WHERE s.encounterid IS NOT NULL AND g.encounterid IS NULL;


-- =====================================================================
-- 4. enc_date = GOLD authoritative date  -- expect 0 off-Gold
--    (biomarkers/AE/ARIA/scores have DATE enc_date; ATT enc_date is TEXT)
-- =====================================================================
SELECT 'biomarkers' t, SUM(CASE WHEN b.enc_date <> g.enc_date OR b.enc_date IS NULL THEN 1 ELSE 0 END) off_gold
FROM ad_mci_prod.admci_biomarkers b JOIN (SELECT DISTINCT encounterid, enc_date FROM rgd_gold_ad.encounters) g ON b.encounterid=g.encounterid
UNION ALL SELECT 'adverse_events', SUM(CASE WHEN a.enc_date <> g.enc_date OR a.enc_date IS NULL THEN 1 ELSE 0 END)
FROM ad_mci_prod.admci_adverse_events a JOIN (SELECT DISTINCT encounterid, enc_date FROM rgd_gold_ad.encounters) g ON a.encounterid=g.encounterid
UNION ALL SELECT 'aria', SUM(CASE WHEN a.enc_date <> g.enc_date OR a.enc_date IS NULL THEN 1 ELSE 0 END)
FROM ad_mci_prod.admci_aria a JOIN (SELECT DISTINCT encounterid, enc_date FROM rgd_gold_ad.encounters) g ON CAST(a.encounterid AS CHAR)=CAST(g.encounterid AS CHAR)
UNION ALL SELECT 'scores', SUM(CASE WHEN s.enc_date <> g.enc_date OR s.enc_date IS NULL THEN 1 ELSE 0 END)
FROM ad_mci_prod.admci_scores s JOIN (SELECT DISTINCT encounterid, enc_date FROM rgd_gold_ad.encounters) g ON s.encounterid=g.encounterid;


-- =====================================================================
-- 5. NULL encounterid  (retained by design; high in biomarkers/scores)
-- =====================================================================
SELECT 'biomarkers' t, SUM(encounterid IS NULL) null_encid, COUNT(*) total FROM ad_mci_prod.admci_biomarkers
UNION ALL SELECT 'adverse_events', SUM(encounterid IS NULL), COUNT(*) FROM ad_mci_prod.admci_adverse_events
UNION ALL SELECT 'att', SUM(encounterid IS NULL), COUNT(*) FROM ad_mci_prod.admci_att_discontinuation
UNION ALL SELECT 'aria', SUM(encounterid IS NULL), COUNT(*) FROM ad_mci_prod.admci_aria
UNION ALL SELECT 'scores', SUM(encounterid IS NULL), COUNT(*) FROM ad_mci_prod.admci_scores;


-- =====================================================================
-- 6. DE-IDENTIFICATION completeness  (evidence/reason nulls)
--    biomarkers has no free-text PHI columns
-- =====================================================================
SELECT 'adverse_events' t, SUM(event_evidence IS NULL) evid_null, SUM(event_reason IS NULL) reason_null, COUNT(*) total FROM ad_mci_prod.admci_adverse_events
UNION ALL SELECT 'att', SUM(discontinuation_evidence IS NULL), SUM(discontinuation_reason IS NULL), COUNT(*) FROM ad_mci_prod.admci_att_discontinuation
UNION ALL SELECT 'aria', SUM(aria_evidence IS NULL), SUM(aria_reason IS NULL), COUNT(*) FROM ad_mci_prod.admci_aria
UNION ALL SELECT 'scores', SUM(score_evidence IS NULL), SUM(score_reason IS NULL), COUNT(*) FROM ad_mci_prod.admci_scores;


-- =====================================================================
-- 7. DUPLICATE ASSESSMENT  (full-row duplicates on delivered columns)
--    NULL-safe: null encid/date fields denote unknown, treated distinct
-- =====================================================================
SELECT 'aria' t,
  COUNT(*)-COUNT(DISTINCT CONCAT_WS('|',CAST(ndid AS CHAR),CAST(encounterid AS CHAR),CAST(aria_date AS CHAR),CAST(aria_type AS CHAR(80)),LEFT(aria_evidence,200))) dupes
FROM ad_mci_prod.admci_aria
UNION ALL SELECT 'att',
  COUNT(*)-COUNT(DISTINCT CONCAT_WS('|',CAST(ndid AS CHAR),CAST(encounterid AS CHAR),discontinuation_date,CAST(drug_name AS CHAR(40)),LEFT(discontinuation_evidence,200)))
FROM ad_mci_prod.admci_att_discontinuation
UNION ALL SELECT 'scores',
  COUNT(*)-COUNT(DISTINCT CONCAT_WS('|',CAST(ndid AS CHAR),CAST(encounterid AS CHAR),score_type,CAST(score_value AS CHAR),CAST(score_date AS CHAR),LEFT(score_evidence,200)))
FROM ad_mci_prod.admci_scores
UNION ALL SELECT 'adverse_events',
  COUNT(*)-COUNT(DISTINCT CONCAT_WS('|',CAST(ndid AS CHAR),CAST(encounterid AS CHAR),CAST(event_name AS CHAR(80)),LEFT(event_onset_date,20),LEFT(event_evidence,200)))
FROM ad_mci_prod.admci_adverse_events
UNION ALL SELECT 'biomarkers',
  COUNT(*)-COUNT(DISTINCT CONCAT_WS('|',CAST(ndid AS CHAR),CAST(encounterid AS CHAR),CAST(test_date AS CHAR),CAST(test_name_std AS CHAR(30)),CAST(biomarker_interpretation AS CHAR(60)),LEFT(result_value,60)))
FROM ad_mci_prod.admci_biomarkers;


-- =====================================================================
-- 8. EVENT DATE vs enc_date  (direction: BEFORE / SAME / AFTER / null)
-- =====================================================================
-- 8a. Biomarkers (test_date, DATE)
SELECT 'biomarkers' t,
  SUM(test_date<enc_date) bef, SUM(test_date=enc_date) sam, SUM(test_date>enc_date) aft,
  SUM(test_date IS NULL OR enc_date IS NULL) null_unp
FROM ad_mci_prod.admci_biomarkers;

-- 8b. Adverse events (event_onset_date TEXT, stored MM-DD-YYYY)
SELECT 'adverse_events' t,
  SUM(STR_TO_DATE(TRIM(event_onset_date),'%m-%d-%Y') < enc_date) bef,
  SUM(STR_TO_DATE(TRIM(event_onset_date),'%m-%d-%Y') = enc_date) sam,
  SUM(STR_TO_DATE(TRIM(event_onset_date),'%m-%d-%Y') > enc_date) aft,
  SUM(event_onset_date IS NULL OR TRIM(event_onset_date)='' OR STR_TO_DATE(TRIM(event_onset_date),'%m-%d-%Y') IS NULL OR enc_date IS NULL) null_unp
FROM ad_mci_prod.admci_adverse_events;

-- 8c. ATT (both enc_date & discontinuation_date TEXT; disc is mixed MM-DD-YYYY / YYYY-MM-DD)
SELECT 'att' t,
  SUM(CASE WHEN TRIM(discontinuation_date) REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(discontinuation_date),'%m-%d-%Y')
           WHEN TRIM(discontinuation_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(discontinuation_date),'%Y-%m-%d') END
      < STR_TO_DATE(enc_date,'%Y-%m-%d')) bef,
  SUM(CASE WHEN TRIM(discontinuation_date) REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(discontinuation_date),'%m-%d-%Y')
           WHEN TRIM(discontinuation_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(discontinuation_date),'%Y-%m-%d') END
      = STR_TO_DATE(enc_date,'%Y-%m-%d')) sam,
  SUM(CASE WHEN TRIM(discontinuation_date) REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(discontinuation_date),'%m-%d-%Y')
           WHEN TRIM(discontinuation_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(discontinuation_date),'%Y-%m-%d') END
      > STR_TO_DATE(enc_date,'%Y-%m-%d')) aft,
  SUM(discontinuation_date IS NULL OR TRIM(discontinuation_date)=''
      OR (TRIM(discontinuation_date) NOT REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
          AND TRIM(discontinuation_date) NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')) null_unp
FROM ad_mci_prod.admci_att_discontinuation;

-- 8d. ARIA (aria_date, DATE)
SELECT 'aria' t,
  SUM(aria_date<enc_date) bef, SUM(aria_date=enc_date) sam, SUM(aria_date>enc_date) aft,
  SUM(aria_date IS NULL OR enc_date IS NULL) null_unp
FROM ad_mci_prod.admci_aria;

-- 8e. Scores (score_date, DATE)
SELECT 'scores' t,
  SUM(score_date<enc_date) bef, SUM(score_date=enc_date) sam, SUM(score_date>enc_date) aft,
  SUM(score_date IS NULL OR enc_date IS NULL) null_unp
FROM ad_mci_prod.admci_scores;


-- =====================================================================
-- 9. DATE PLAUSIBILITY  (future > cutoff/today, pre-2000)  -- DATE cols
-- =====================================================================
SELECT 'bio test_date' c, SUM(test_date>'2026-08-26') future, SUM(test_date<'2000-01-01') old FROM ad_mci_prod.admci_biomarkers
UNION ALL SELECT 'bio enc_date',    SUM(enc_date>'2026-08-26'),  SUM(enc_date<'2000-01-01')  FROM ad_mci_prod.admci_biomarkers
UNION ALL SELECT 'AE enc_date',     SUM(enc_date>'2026-08-26'),  SUM(enc_date<'2000-01-01')  FROM ad_mci_prod.admci_adverse_events
UNION ALL SELECT 'ARIA aria_date',  SUM(aria_date>'2026-08-26'), SUM(aria_date<'2000-01-01') FROM ad_mci_prod.admci_aria
UNION ALL SELECT 'ARIA enc_date',   SUM(enc_date>'2026-08-26'),  SUM(enc_date<'2000-01-01')  FROM ad_mci_prod.admci_aria
UNION ALL SELECT 'scores enc_date', SUM(enc_date>'2026-08-26'),  SUM(enc_date<'2000-01-01')  FROM ad_mci_prod.admci_scores
UNION ALL SELECT 'scores score_date',SUM(score_date>'2026-08-26'),SUM(score_date<'2000-01-01') FROM ad_mci_prod.admci_scores;


-- =====================================================================
-- 10. enc_date RANGE per table  (coverage + cutoff held; DATE cols)
-- =====================================================================
SELECT 'biomarkers' t, MIN(enc_date) mn, MAX(enc_date) mx FROM ad_mci_prod.admci_biomarkers
UNION ALL SELECT 'adverse_events', MIN(enc_date), MAX(enc_date) FROM ad_mci_prod.admci_adverse_events
UNION ALL SELECT 'aria', MIN(enc_date), MAX(enc_date) FROM ad_mci_prod.admci_aria
UNION ALL SELECT 'scores', MIN(enc_date), MAX(enc_date) FROM ad_mci_prod.admci_scores;


-- =====================================================================
-- 11. SCORE VALUE VALIDITY  (valid instrument range 0-30)
-- =====================================================================
SELECT score_type,
  COUNT(*) total,
  SUM(score_value BETWEEN 0 AND 30) in_range,
  SUM(score_value < 0 OR score_value > 30) out_of_range,
  SUM(score_value IS NULL) null_value
FROM ad_mci_prod.admci_scores
GROUP BY score_type
ORDER BY total DESC;

-- 11b. List the out-of-range score rows (extraction artifacts)
SELECT id, ndid, encounterid, enc_date, score_date, score_type, score_value, LEFT(score_evidence,120) evidence
FROM ad_mci_prod.admci_scores
WHERE score_value < 0 OR score_value > 30
ORDER BY score_type, score_value DESC;


-- =====================================================================
-- 12. CATEGORICAL VALUE PROFILING  (spot junk / unexpected categories)
-- =====================================================================
SELECT 'aria_status' col, aria_status val, COUNT(*) n FROM ad_mci_prod.admci_aria GROUP BY aria_status
UNION ALL SELECT 'symptomatic_flag', symptomatic_flag, COUNT(*) FROM ad_mci_prod.admci_aria GROUP BY symptomatic_flag
UNION ALL SELECT 'score_type', score_type, COUNT(*) FROM ad_mci_prod.admci_scores GROUP BY score_type
UNION ALL SELECT 'event_status', CAST(event_status AS CHAR(30)), COUNT(*) FROM ad_mci_prod.admci_adverse_events GROUP BY CAST(event_status AS CHAR(30))
ORDER BY col, n DESC;


-- =====================================================================
-- 13. SOURCE-TABLE CAVEATS (rgd_gold_ad.medication) — context, not deliverable QC
-- =====================================================================
-- Aduhelm records dated after Nov-2024 market withdrawal (impossible)
SELECT COUNT(*) aduhelm_post_withdrawal
FROM rgd_gold_ad.medication
WHERE UPPER(CAST(med_name AS CHAR(40)))='ADUHELM' AND medication_start_date > '2024-11-01';

-- medication_end_date max (projected/placeholder values far in the future)
SELECT MAX(medication_end_date) max_med_end_date FROM rgd_gold_ad.medication;

-- Gold patient roster size
SELECT COUNT(*) gold_patients FROM rgd_gold_ad.patients;


-- =====================================================================
-- 14. DATA DICTIONARY — column/type listing for all delivered tables
-- =====================================================================
SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA='ad_mci_prod'
  AND TABLE_NAME IN ('admci_biomarkers','admci_adverse_events',
                     'admci_att_discontinuation','admci_aria','admci_scores')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
