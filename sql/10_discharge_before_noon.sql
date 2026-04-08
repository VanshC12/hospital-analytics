-- ============================================================
-- Discharge Before Noon (DBN) - Throughput KPI
-- ============================================================
-- DBN is the #1 throughput metric at academic medical centers.
-- Late discharges create downstream capacity problems:
--   - ED patients can't get inpatient beds
--   - Surgical patients can't move to recovery floors  
--   - Ambulances get diverted
--   - Revenue per bed decreases
--
-- Cleveland Clinic, Mayo, Stanford, and Cedars-Sinai all
-- track this daily with goals of 30-50% DBN.
-- ============================================================

WITH inpatient_discharges AS (
    SELECT 
        e.id AS encounter_id,
        e.start AS admission_dt,
        e.stop AS discharge_dt,
        EXTRACT(HOUR FROM e.stop) AS discharge_hour,
        EXTRACT(DOW FROM e.stop) AS discharge_dow,
        EXTRACT(EPOCH FROM (e.stop - e.start)) / 86400.0 AS los_days,
        CASE WHEN EXTRACT(HOUR FROM e.stop) < 12 THEN 1 ELSE 0 END AS discharged_before_noon
    FROM encounters e
    WHERE e.encounterclass = 'inpatient'
      AND e.stop IS NOT NULL
),

combined AS (
    -- Overall row
    SELECT 
        0 AS sort_order,
        'OVERALL' AS time_window,
        COUNT(*) AS total_discharges,
        SUM(discharged_before_noon) AS dbn_count,
        ROUND(100.0 * SUM(discharged_before_noon) / NULLIF(COUNT(*), 0), 2) AS dbn_rate_pct,
        ROUND(AVG(los_days)::numeric, 2) AS avg_los_days,
        ROUND(AVG(discharge_hour)::numeric, 1) AS avg_discharge_hour
    FROM inpatient_discharges

    UNION ALL

    -- Day of week breakdown
    SELECT 
        (discharge_dow + 1)::int AS sort_order,
        CASE discharge_dow
            WHEN 0 THEN 'Sunday'
            WHEN 1 THEN 'Monday'
            WHEN 2 THEN 'Tuesday'
            WHEN 3 THEN 'Wednesday'
            WHEN 4 THEN 'Thursday'
            WHEN 5 THEN 'Friday'
            WHEN 6 THEN 'Saturday'
        END AS time_window,
        COUNT(*) AS total_discharges,
        SUM(discharged_before_noon) AS dbn_count,
        ROUND(100.0 * SUM(discharged_before_noon) / NULLIF(COUNT(*), 0), 2) AS dbn_rate_pct,
        ROUND(AVG(los_days)::numeric, 2) AS avg_los_days,
        ROUND(AVG(discharge_hour)::numeric, 1) AS avg_discharge_hour
    FROM inpatient_discharges
    GROUP BY discharge_dow
)

SELECT 
    time_window,
    total_discharges,
    dbn_count,
    dbn_rate_pct,
    avg_los_days,
    avg_discharge_hour
FROM combined
ORDER BY sort_order;
