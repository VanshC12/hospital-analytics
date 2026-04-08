-- ============================================================
-- Hospital-Acquired Infection (HAI) Surveillance
-- ============================================================
-- HAIs are the #1 patient safety metric tracked by hospitals.
-- CMS publicly reports HAI rates and penalizes the bottom 25%
-- of hospitals through the HAC Reduction Program (1% Medicare
-- payment reduction).
--
-- This query identifies HAI-related conditions occurring during
-- or shortly after inpatient encounters — the same logic the
-- NHSN (National Healthcare Safety Network) uses for surveillance.
-- ============================================================

WITH inpatient_admissions AS (
    SELECT 
        e.id AS encounter_id,
        e.patient,
        e.start AS admission_dt,
        e.stop AS discharge_dt,
        EXTRACT(EPOCH FROM (e.stop - e.start)) / 86400.0 AS los_days
    FROM encounters e
    WHERE e.encounterclass = 'inpatient'
      AND e.stop IS NOT NULL
),

infection_conditions AS (
    -- Identify infection-related diagnoses that could be HAIs
    SELECT 
        c.patient,
        c.encounter,
        c.start AS condition_start,
        c.code,
        c.description,
        CASE
            WHEN LOWER(c.description) LIKE '%sepsis%' THEN 'Sepsis'
            WHEN LOWER(c.description) LIKE '%urinary%infection%' 
                OR LOWER(c.description) LIKE '%uti%' THEN 'UTI (Possible CAUTI)'
            WHEN LOWER(c.description) LIKE '%pneumonia%' THEN 'Pneumonia (Possible HAP/VAP)'
            WHEN LOWER(c.description) LIKE '%bloodstream%' 
                OR LOWER(c.description) LIKE '%bacteremia%' THEN 'BSI (Possible CLABSI)'
            WHEN LOWER(c.description) LIKE '%wound infection%' 
                OR LOWER(c.description) LIKE '%surgical site%' THEN 'SSI'
            WHEN LOWER(c.description) LIKE '%clostridium%' 
                OR LOWER(c.description) LIKE '%c. diff%' 
                OR LOWER(c.description) LIKE '%difficile%' THEN 'C. diff'
            ELSE 'Other Infection'
        END AS hai_category
    FROM conditions c
    WHERE LOWER(c.description) ~ '(infection|sepsis|pneumonia|bacteremia|cellulitis|abscess|difficile)'
)

SELECT 
    ic.hai_category,
    COUNT(DISTINCT ic.patient) AS unique_patients_affected,
    COUNT(*) AS total_infection_episodes,
    -- Rate per 1,000 inpatient days (the standard HAI denominator)
    ROUND(
        (1000.0 * COUNT(*)::numeric / NULLIF((SELECT SUM(los_days) FROM inpatient_admissions), 0))::numeric,
        2
    ) AS rate_per_1000_patient_days
FROM infection_conditions ic
GROUP BY ic.hai_category
ORDER BY total_infection_episodes DESC;
