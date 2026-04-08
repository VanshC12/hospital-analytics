-- ============================================================
-- Mortality Index — Observed vs Expected (O/E Ratio)
-- ============================================================
-- The "O/E ratio" is the gold-standard quality metric in US
-- hospitals. CMS uses risk-adjusted mortality in Star Ratings,
-- US News uses it in rankings, and boards evaluate CMOs by it.
--
-- Methodology:
--   1. Identify all inpatient stays (denominator)
--   2. Flag deaths within 30 days of admission (observed)
--   3. Calculate expected mortality using age-stratified rates
--      (in production, hospitals use CMS hierarchical models or
--       Vizient's risk adjustment — we use age strata as a proxy)
--   4. Compute O/E ratio
-- ============================================================

WITH inpatient_cohort AS (
    SELECT 
        e.id AS encounter_id,
        e.patient,
        e.start AS admission_dt,
        e.stop AS discharge_dt,
        p.birthdate,
        p.deathdate,
        p.race,
        p.ethnicity,
        EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) AS age_at_admission,
        -- Did the patient die within 30 days of admission?
        CASE 
            WHEN p.deathdate IS NOT NULL 
                AND p.deathdate >= e.start::date 
                AND p.deathdate <= (e.start + INTERVAL '30 days')::date
            THEN 1 ELSE 0 
        END AS died_within_30d
    FROM encounters e
    JOIN patients p ON e.patient = p.id
    WHERE e.encounterclass = 'inpatient'
),

age_stratified AS (
    SELECT 
        *,
        CASE 
            WHEN age_at_admission < 45 THEN '18-44'
            WHEN age_at_admission < 65 THEN '45-64'
            WHEN age_at_admission < 75 THEN '65-74'
            WHEN age_at_admission < 85 THEN '75-84'
            ELSE '85+'
        END AS age_band,
        -- Expected mortality rates from published acute care benchmarks
        -- (In real hospitals, this comes from CMS or Vizient risk models)
        CASE 
            WHEN age_at_admission < 45 THEN 0.005   -- 0.5% expected
            WHEN age_at_admission < 65 THEN 0.020   -- 2.0% expected
            WHEN age_at_admission < 75 THEN 0.045   -- 4.5% expected
            WHEN age_at_admission < 85 THEN 0.085   -- 8.5% expected
            ELSE 0.150                              -- 15% expected
        END AS expected_mortality_rate
    FROM inpatient_cohort
)

-- Final O/E calculation by age band
SELECT 
    age_band,
    COUNT(*) AS total_admissions,
    SUM(died_within_30d) AS observed_deaths,
    ROUND(100.0 * SUM(died_within_30d) / NULLIF(COUNT(*), 0), 2) AS observed_mortality_rate_pct,
    ROUND(100.0 * AVG(expected_mortality_rate)::numeric, 2) AS expected_mortality_rate_pct,
    ROUND(SUM(expected_mortality_rate)::numeric, 2) AS expected_deaths,
    ROUND(
        (SUM(died_within_30d)::numeric / NULLIF(SUM(expected_mortality_rate), 0))::numeric, 
        3
    ) AS oe_ratio,
    CASE 
        WHEN SUM(died_within_30d)::numeric / NULLIF(SUM(expected_mortality_rate), 0) < 0.85 THEN '✅ Better than expected'
        WHEN SUM(died_within_30d)::numeric / NULLIF(SUM(expected_mortality_rate), 0) <= 1.15 THEN '➖ As expected'
        ELSE '🚨 Worse than expected'
    END AS performance_flag
FROM age_stratified
GROUP BY age_band
ORDER BY age_band;
