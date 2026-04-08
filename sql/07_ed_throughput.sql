-- ============================================================
-- Emergency Department Throughput Analysis
-- ============================================================
-- ED throughput is the #1 operational metric for hospital CEOs.
-- CMS publicly reports "Median Time from ED Arrival to ED 
-- Departure" — the OP-18 quality measure. This query mirrors
-- that calculation plus disposition analysis.
--
-- Key metrics:
--   - ED visit volume (capacity planning)
--   - Median LOS in ED (the OP-18 measure)
--   - 90th percentile LOS (the boarding cases)
--   - Disposition mix (admit rate, discharge rate)
--   - Time of day patterns (staffing optimization)
-- ============================================================

WITH ed_visits AS (
    SELECT 
        e.id AS encounter_id,
        e.patient,
        e.start AS arrival_dt,
        e.stop AS departure_dt,
        e.reasondescription AS chief_complaint,
        e.total_claim_cost,
        EXTRACT(EPOCH FROM (e.stop - e.start)) / 60.0 AS los_minutes,
        EXTRACT(HOUR FROM e.start) AS arrival_hour,
        EXTRACT(DOW FROM e.start) AS day_of_week,
        -- Was this patient admitted to inpatient within 1 day?
        EXISTS (
            SELECT 1 FROM encounters e2
            WHERE e2.patient = e.patient
              AND e2.encounterclass = 'inpatient'
              AND e2.start >= e.start
              AND e2.start <= e.stop + INTERVAL '6 hours'
        ) AS admitted_to_inpatient
    FROM encounters e
    WHERE e.encounterclass = 'emergency'
      AND e.stop IS NOT NULL
      AND e.stop > e.start
)

-- Overall ED throughput summary
SELECT 
    'OVERALL' AS metric_group,
    COUNT(*) AS ed_visits,
    ROUND(AVG(los_minutes)::numeric, 1) AS avg_los_minutes,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY los_minutes)::numeric, 1) AS median_los_minutes,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY los_minutes)::numeric, 1) AS p90_los_minutes,
    SUM(CASE WHEN admitted_to_inpatient THEN 1 ELSE 0 END) AS admitted_count,
    ROUND(100.0 * SUM(CASE WHEN admitted_to_inpatient THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS admit_rate_pct,
    ROUND(AVG(total_claim_cost)::numeric, 2) AS avg_cost_per_visit
FROM ed_visits

UNION ALL

-- Throughput by disposition (admitted vs discharged from ED)
SELECT 
    CASE WHEN admitted_to_inpatient THEN 'ADMITTED' ELSE 'DISCHARGED' END AS metric_group,
    COUNT(*) AS ed_visits,
    ROUND(AVG(los_minutes)::numeric, 1) AS avg_los_minutes,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY los_minutes)::numeric, 1) AS median_los_minutes,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY los_minutes)::numeric, 1) AS p90_los_minutes,
    NULL AS admitted_count,
    NULL AS admit_rate_pct,
    ROUND(AVG(total_claim_cost)::numeric, 2) AS avg_cost_per_visit
FROM ed_visits
GROUP BY admitted_to_inpatient
ORDER BY metric_group;
