
-- ============================================================
-- ML Training Dataset: Readmission Prediction
-- ============================================================
-- Creates a table with features for XGBoost training
-- Then export to CSV with: \COPY ml_readmission_training TO 'ml/data/readmission_training.csv' CSV HEADER
-- ============================================================

DROP TABLE IF EXISTS ml_readmission_training;

CREATE TABLE ml_readmission_training AS
WITH inpatient_index AS (
    SELECT 
        e.id AS encounter_id,
        e.patient,
        e.start AS admission_date,
        e.stop AS discharge_date,
        e.total_claim_cost,
        p.birthdate,
        p.race,
        p.ethnicity,
        p.gender,
        EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) AS age_at_admission,
        EXTRACT(EPOCH FROM (e.stop - e.start))/86400.0 AS length_of_stay_days,
        EXTRACT(YEAR FROM e.start) AS admission_year,
        EXTRACT(MONTH FROM e.start) AS admission_month,
        EXTRACT(DOW FROM e.start) AS admission_dow
    FROM encounters e
    JOIN patients p ON e.patient = p.id
    WHERE e.encounterclass = 'inpatient'
      AND e.stop IS NOT NULL
),

readmission_flag AS (
    SELECT 
        i1.*,
        CASE WHEN i2.encounter_id IS NOT NULL THEN 1 ELSE 0 END AS was_readmitted_30d
    FROM inpatient_index i1
    LEFT JOIN inpatient_index i2 
        ON i1.patient = i2.patient
        AND i2.admission_date > i1.discharge_date
        AND i2.admission_date <= i1.discharge_date + INTERVAL '30 days'
),

prior_history AS (
    SELECT 
        rf.encounter_id,
        COUNT(DISTINCT prior.encounter_id) AS prior_admissions_1yr,
        COALESCE(MIN(EXTRACT(DAY FROM (rf.admission_date - prior.discharge_date))), 999) AS days_since_last_admission
    FROM readmission_flag rf
    LEFT JOIN inpatient_index prior
        ON rf.patient = prior.patient
        AND prior.discharge_date < rf.admission_date
        AND prior.discharge_date >= rf.admission_date - INTERVAL '365 days'
    GROUP BY rf.encounter_id
),

condition_counts AS (
    SELECT 
        rf.encounter_id,
        COUNT(DISTINCT c.code) AS num_conditions
    FROM readmission_flag rf
    LEFT JOIN conditions c 
        ON c.patient = rf.patient
        AND c.start <= rf.admission_date
        AND (c.stop IS NULL OR c.stop >= rf.admission_date)
    GROUP BY rf.encounter_id
),

medication_counts AS (
    SELECT 
        rf.encounter_id,
        COUNT(DISTINCT m.code) AS num_active_meds
    FROM readmission_flag rf
    LEFT JOIN medications m
        ON m.patient = rf.patient
        AND m.start <= rf.admission_date
        AND (m.stop IS NULL OR m.stop >= rf.admission_date)
    GROUP BY rf.encounter_id
),

procedure_counts AS (
    SELECT 
        rf.encounter_id,
        COUNT(DISTINCT pr.code) AS num_procedures
    FROM readmission_flag rf
    LEFT JOIN procedures pr 
        ON pr.encounter = rf.encounter_id
    GROUP BY rf.encounter_id
),

ed_utilization AS (
    SELECT 
        rf.encounter_id,
        COUNT(DISTINCT ed.id) AS ed_visits_6mo
    FROM readmission_flag rf
    LEFT JOIN encounters ed
        ON ed.patient = rf.patient
        AND ed.encounterclass = 'emergency'
        AND ed.start < rf.admission_date
        AND ed.start >= rf.admission_date - INTERVAL '180 days'
    GROUP BY rf.encounter_id
)

SELECT 
    rf.encounter_id,
    rf.patient,
    rf.was_readmitted_30d,
    rf.age_at_admission,
    rf.length_of_stay_days,
    rf.total_claim_cost,
    rf.admission_year,
    rf.admission_month,
    rf.admission_dow,
    COALESCE(ph.prior_admissions_1yr, 0) AS prior_admissions_1yr,
    COALESCE(ph.days_since_last_admission, 999) AS days_since_last_admission,
    COALESCE(cc.num_conditions, 0) AS num_conditions,
    COALESCE(mc.num_active_meds, 0) AS num_active_meds,
    COALESCE(pc.num_procedures, 0) AS num_procedures,
    COALESCE(eu.ed_visits_6mo, 0) AS ed_visits_6mo,
    rf.race,
    rf.ethnicity,
    rf.gender
FROM readmission_flag rf
LEFT JOIN prior_history ph ON rf.encounter_id = ph.encounter_id
LEFT JOIN condition_counts cc ON rf.encounter_id = cc.encounter_id
LEFT JOIN medication_counts mc ON rf.encounter_id = mc.encounter_id
LEFT JOIN procedure_counts pc ON rf.encounter_id = pc.encounter_id
LEFT JOIN ed_utilization eu ON rf.encounter_id = eu.encounter_id
ORDER BY rf.admission_date;
