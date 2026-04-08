-- ============================================================
-- 30-Day Readmission Rate by Demographics
-- Mirrors CMS Health Equity Index (HEI) reporting requirements
-- ============================================================
-- Stratifies HRRP readmission rate across patient demographics to
-- identify disparities. The CMS Health Equity Index was added to
-- the Hospital Star Rating in 2024 specifically to measure this.
-- ============================================================

WITH inpatient_stays AS (
    SELECT 
        e.id AS encounter_id,
        e.patient,
        e.start AS admission_date,
        e.stop AS discharge_date,
        p.race,
        p.ethnicity,
        p.gender,
        EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) AS age_at_admission,
        CASE 
            WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 18 THEN '0-17'
            WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 45 THEN '18-44'
            WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 65 THEN '45-64'
            WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 75 THEN '65-74'
            ELSE '75+'
        END AS age_group
    FROM encounters e
    JOIN patients p ON e.patient = p.id
    WHERE e.encounterclass = 'inpatient'
      AND e.stop IS NOT NULL
),

readmissions AS (
    SELECT 
        i1.encounter_id,
        i1.patient,
        i1.race,
        i1.ethnicity,
        i1.gender,
        i1.age_group,
        CASE WHEN i2.encounter_id IS NOT NULL THEN 1 ELSE 0 END AS is_readmitted
    FROM inpatient_stays i1
    LEFT JOIN inpatient_stays i2 
        ON i1.patient = i2.patient
        AND i2.admission_date > i1.discharge_date
        AND i2.admission_date <= i1.discharge_date + INTERVAL '30 days'
)

-- Stratified analysis by race and ethnicity
SELECT 
    race,
    ethnicity,
    COUNT(*) AS total_admissions,
    SUM(is_readmitted) AS readmissions,
    ROUND(100.0 * SUM(is_readmitted) / NULLIF(COUNT(*), 0), 2) AS readmission_rate_pct
FROM readmissions
GROUP BY race, ethnicity
HAVING COUNT(*) >= 10  -- Suppress small cells for statistical reliability
ORDER BY readmission_rate_pct DESC;
