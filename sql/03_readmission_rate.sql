-- ============================================================
-- 30-Day Readmission Rate Analysis
-- Mirrors CMS HRRP (Hospital Readmissions Reduction Program) logic
-- ============================================================
-- A "readmission" is defined as any unplanned inpatient admission
-- within 30 days of discharge from a previous inpatient stay.
-- 
-- This is the same logic CMS uses to penalize hospitals up to 3%
-- of their Medicare reimbursement under HRRP.
-- ============================================================

WITH inpatient_stays AS (
    -- Step 1: Get all inpatient encounters (the index admissions)
    SELECT 
        e.id AS encounter_id,
        e.patient,
        e.start AS admission_date,
        e.stop AS discharge_date,
        e.organization,
        e.total_claim_cost,
        e.reasondescription AS admission_reason,
        p.race,
        p.ethnicity,
        p.gender,
        EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) AS age_at_admission
    FROM encounters e
    JOIN patients p ON e.patient = p.id
    WHERE e.encounterclass = 'inpatient'
      AND e.stop IS NOT NULL
),

readmissions AS (
    -- Step 2: For each inpatient stay, find any subsequent inpatient
    -- stay for the SAME patient within 30 days of discharge
    SELECT 
        i1.encounter_id AS index_encounter,
        i1.patient,
        i1.admission_date AS index_admission,
        i1.discharge_date AS index_discharge,
        i1.age_at_admission,
        i1.race,
        i1.ethnicity,
        i1.gender,
        i1.admission_reason,
        i2.encounter_id AS readmit_encounter,
        i2.admission_date AS readmit_date,
        EXTRACT(DAY FROM (i2.admission_date - i1.discharge_date)) AS days_to_readmit
    FROM inpatient_stays i1
    LEFT JOIN inpatient_stays i2 
        ON i1.patient = i2.patient
        AND i2.admission_date > i1.discharge_date
        AND i2.admission_date <= i1.discharge_date + INTERVAL '30 days'
)

-- Step 3: Calculate the readmission rate
SELECT 
    COUNT(*) AS total_inpatient_stays,
    COUNT(readmit_encounter) AS total_readmissions,
    ROUND(100.0 * COUNT(readmit_encounter) / NULLIF(COUNT(*), 0), 2) AS readmission_rate_pct,
    ROUND(AVG(days_to_readmit), 1) AS avg_days_to_readmit
FROM readmissions;
