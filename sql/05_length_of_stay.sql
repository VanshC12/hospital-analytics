-- ============================================================
-- Length of Stay (LOS) Analysis by Service Line
-- ============================================================
-- LOS is the #1 operational efficiency metric in US hospitals.
-- This query mirrors the daily LOS report run at every major
-- hospital quality team (Cedars-Sinai, UCLA Health, Stanford).
-- 
-- Key metrics calculated:
--   - ALOS (Average Length of Stay) by encounter class
--   - Median LOS (more robust than average for skewed data)
--   - 90th percentile LOS (catches the long-stay outliers)
--   - GMLOS comparison opportunity (CMS Geometric Mean LOS)
-- ============================================================

WITH stay_durations AS (
    SELECT 
        e.id AS encounter_id,
        e.patient,
        e.encounterclass,
        e.organization,
        e.description AS visit_type,
        e.reasondescription AS primary_reason,
        e.total_claim_cost,
        e.start AS admission_dt,
        e.stop AS discharge_dt,
        -- LOS in days (the standard hospital metric)
        EXTRACT(EPOCH FROM (e.stop - e.start)) / 86400.0 AS los_days,
        p.race,
        p.ethnicity,
        EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) AS age_at_admission
    FROM encounters e
    JOIN patients p ON e.patient = p.id
    WHERE e.encounterclass IN ('inpatient', 'emergency', 'snf', 'hospice')
      AND e.stop IS NOT NULL
      AND e.stop > e.start
)

SELECT 
    encounterclass AS service_line,
    COUNT(*) AS total_stays,
    -- Average LOS (what most reports show, but skewed by outliers)
    ROUND(AVG(los_days)::numeric, 2) AS avg_los_days,
    -- Median LOS (more accurate, what quality teams prefer)
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY los_days)::numeric, 2) AS median_los_days,
    -- 90th percentile (catches the long stays driving costs)
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY los_days)::numeric, 2) AS p90_los_days,
    -- Total bed-days consumed (capacity metric)
    ROUND(SUM(los_days)::numeric, 0) AS total_bed_days,
    -- Average cost per stay
    ROUND(AVG(total_claim_cost)::numeric, 2) AS avg_cost_per_stay,
    -- Cost per day (efficiency benchmark)
    ROUND((SUM(total_claim_cost) / NULLIF(SUM(los_days), 0))::numeric, 2) AS cost_per_day
FROM stay_durations
GROUP BY encounterclass
ORDER BY total_bed_days DESC;o

