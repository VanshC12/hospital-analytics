-- ============================================================
-- Patient Experience Proxy Metrics (HCAHPS-Adjacent)
-- ============================================================
-- HCAHPS surveys take 3-6 months to come back from CMS, so
-- hospitals build "leading indicator" dashboards using EHR data
-- to predict patient experience scores BEFORE the survey lands.
-- ============================================================

WITH patient_metrics AS (
    SELECT 
        p.id AS patient_id,
        COUNT(DISTINCT e.id) AS total_encounters,
        COUNT(DISTINCT e.provider) AS unique_providers,
        ROUND(
            (COUNT(DISTINCT e.provider)::numeric / NULLIF(COUNT(DISTINCT e.id), 0))::numeric,
            3
        ) AS continuity_ratio,
        (SELECT COUNT(DISTINCT c.code) FROM conditions c WHERE c.patient = p.id) AS unique_conditions,
        SUM(CASE WHEN e.encounterclass = 'inpatient' THEN 1 ELSE 0 END) AS inpatient_stays,
        ROUND(
            AVG(
                CASE WHEN e.encounterclass = 'emergency' 
                     THEN EXTRACT(EPOCH FROM (e.stop - e.start))/60.0 
                END
            )::numeric,
            1
        ) AS avg_ed_minutes
    FROM patients p
    LEFT JOIN encounters e ON e.patient = p.id
    WHERE e.id IS NOT NULL
    GROUP BY p.id
),

tiered_patients AS (
    SELECT 
        *,
        CASE 
            WHEN continuity_ratio <= 0.3 THEN 1
            WHEN continuity_ratio <= 0.5 THEN 2
            WHEN continuity_ratio <= 0.7 THEN 3
            ELSE 4
        END AS tier_rank,
        CASE 
            WHEN continuity_ratio <= 0.3 THEN '⭐⭐⭐⭐⭐ Excellent Continuity'
            WHEN continuity_ratio <= 0.5 THEN '⭐⭐⭐⭐ Good Continuity'
            WHEN continuity_ratio <= 0.7 THEN '⭐⭐⭐ Moderate Continuity'
            ELSE '⭐⭐ Poor Continuity (Risk)'
        END AS experience_tier
    FROM patient_metrics
)

SELECT 
    experience_tier,
    COUNT(*) AS patients,
    ROUND(AVG(total_encounters)::numeric, 1) AS avg_encounters,
    ROUND(AVG(unique_providers)::numeric, 1) AS avg_providers_seen,
    ROUND(AVG(continuity_ratio)::numeric, 3) AS avg_continuity_ratio,
    ROUND(AVG(unique_conditions)::numeric, 1) AS avg_conditions,
    ROUND(AVG(inpatient_stays)::numeric, 1) AS avg_inpatient_stays,
    ROUND(AVG(avg_ed_minutes)::numeric, 1) AS avg_ed_wait_minutes
FROM tiered_patients
GROUP BY experience_tier, tier_rank
ORDER BY tier_rank;
