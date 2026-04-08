-- ============================================================
-- Data Quality Test Suite
-- ============================================================
-- Production hospital data teams run these checks daily.
-- Every test returns either PASS or FAIL with context.
-- 
-- Test categories:
--   1. Row count sanity checks (did data load correctly?)
--   2. Referential integrity (do foreign keys resolve?)
--   3. Null rate checks (are required fields populated?)
--   4. Date logic checks (discharge after admission, etc.)
--   5. Value range checks (ages 0-120, costs >= 0, etc.)
--   6. Query-specific business logic tests
-- ============================================================

\echo '============================================================'
\echo '🏥 HOSPITAL ANALYTICS - DATA QUALITY TEST SUITE'
\echo '============================================================'
\echo ''

-- ============================================================
-- CATEGORY 1: ROW COUNT SANITY CHECKS
-- ============================================================
\echo '📊 CATEGORY 1: Row Count Sanity Checks'
\echo '------------------------------------------------------------'

SELECT 
    'TEST 1.1: Patients table has rows' AS test_name,
    CASE WHEN COUNT(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS actual_value,
    '> 0' AS expected
FROM patients;

SELECT 
    'TEST 1.2: Encounters table has rows' AS test_name,
    CASE WHEN COUNT(*) > 1000 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS actual_value,
    '> 1000' AS expected
FROM encounters;

SELECT 
    'TEST 1.3: Observations table has rows' AS test_name,
    CASE WHEN COUNT(*) > 10000 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS actual_value,
    '> 10000' AS expected
FROM observations;

SELECT 
    'TEST 1.4: Conditions table has rows' AS test_name,
    CASE WHEN COUNT(*) > 1000 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS actual_value,
    '> 1000' AS expected
FROM conditions;

-- ============================================================
-- CATEGORY 2: REFERENTIAL INTEGRITY
-- ============================================================
\echo ''
\echo '🔗 CATEGORY 2: Referential Integrity'
\echo '------------------------------------------------------------'

SELECT 
    'TEST 2.1: All encounter patients exist in patients table' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS orphaned_rows,
    '0 orphans' AS expected
FROM encounters e
LEFT JOIN patients p ON e.patient = p.id
WHERE p.id IS NULL;

SELECT 
    'TEST 2.2: All condition patients exist in patients table' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS orphaned_rows,
    '0 orphans' AS expected
FROM conditions c
LEFT JOIN patients p ON c.patient = p.id
WHERE p.id IS NULL;

SELECT 
    'TEST 2.3: All medication patients exist in patients table' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS orphaned_rows,
    '0 orphans' AS expected
FROM medications m
LEFT JOIN patients p ON m.patient = p.id
WHERE p.id IS NULL;

-- ============================================================
-- CATEGORY 3: NULL RATE CHECKS
-- ============================================================
\echo ''
\echo '🕳️  CATEGORY 3: Null Rate Checks (critical fields)'
\echo '------------------------------------------------------------'

SELECT 
    'TEST 3.1: Patient birthdate is never null' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS null_count,
    '0 nulls' AS expected
FROM patients
WHERE birthdate IS NULL;

SELECT 
    'TEST 3.2: Encounter start date is never null' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS null_count,
    '0 nulls' AS expected
FROM encounters
WHERE start IS NULL;

SELECT 
    'TEST 3.3: Encounter class is never null' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS null_count,
    '0 nulls' AS expected
FROM encounters
WHERE encounterclass IS NULL;

SELECT 
    'TEST 3.4: Patient race populated (>95% required)' AS test_name,
    CASE WHEN (100.0 * COUNT(*) FILTER (WHERE race IS NOT NULL) / NULLIF(COUNT(*), 0)) >= 95 
         THEN '✅ PASS' ELSE '⚠️  WARN' END AS result,
    ROUND(100.0 * COUNT(*) FILTER (WHERE race IS NOT NULL) / NULLIF(COUNT(*), 0), 2) AS pct_populated,
    '>= 95%' AS expected
FROM patients;

-- ============================================================
-- CATEGORY 4: DATE LOGIC CHECKS
-- ============================================================
\echo ''
\echo '📅 CATEGORY 4: Date Logic Checks'
\echo '------------------------------------------------------------'

SELECT 
    'TEST 4.1: Encounter stop is after start' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS invalid_rows,
    '0 invalid dates' AS expected
FROM encounters
WHERE stop IS NOT NULL AND stop < start;

SELECT 
    'TEST 4.2: Patient deathdate is after birthdate' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS invalid_rows,
    '0 invalid dates' AS expected
FROM patients
WHERE deathdate IS NOT NULL AND deathdate < birthdate;

SELECT 
    'TEST 4.3: Condition stop is after start (when not null)' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS invalid_rows,
    '0 invalid dates' AS expected
FROM conditions
WHERE stop IS NOT NULL AND stop < start;

-- ============================================================
-- CATEGORY 5: VALUE RANGE CHECKS
-- ============================================================
\echo ''
\echo '📏 CATEGORY 5: Value Range Checks'
\echo '------------------------------------------------------------'

SELECT 
    'TEST 5.1: Patient ages are reasonable (0-120)' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS out_of_range,
    '0 out of range' AS expected
FROM patients
WHERE EXTRACT(YEAR FROM AGE(COALESCE(deathdate, CURRENT_DATE), birthdate)) NOT BETWEEN 0 AND 120;

SELECT 
    'TEST 5.2: Encounter costs are non-negative' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS negative_costs,
    '0 negative costs' AS expected
FROM encounters
WHERE total_claim_cost < 0;

SELECT 
    'TEST 5.3: Income values are non-negative' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(*) AS negative_income,
    '0 negative' AS expected
FROM patients
WHERE income IS NOT NULL AND income < 0;

-- ============================================================
-- CATEGORY 6: QUERY-SPECIFIC BUSINESS LOGIC TESTS
-- ============================================================
\echo ''
\echo '🧪 CATEGORY 6: Query-Specific Business Logic'
\echo '------------------------------------------------------------'

-- Readmission rate should be between 0 and 100
WITH inpatient_stays AS (
    SELECT e.id AS encounter_id, e.patient, e.start AS admission_date, e.stop AS discharge_date
    FROM encounters e WHERE e.encounterclass = 'inpatient' AND e.stop IS NOT NULL
),
readmissions AS (
    SELECT 
        COUNT(*) AS total_stays,
        COUNT(i2.encounter_id) AS readmits
    FROM inpatient_stays i1
    LEFT JOIN inpatient_stays i2 
        ON i1.patient = i2.patient
        AND i2.admission_date > i1.discharge_date
        AND i2.admission_date <= i1.discharge_date + INTERVAL '30 days'
)
SELECT 
    'TEST 6.1: Readmission rate is within plausible range (0-50%)' AS test_name,
    CASE WHEN (100.0 * readmits / NULLIF(total_stays, 0)) BETWEEN 0 AND 50 
         THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    ROUND((100.0 * readmits / NULLIF(total_stays, 0))::numeric, 2) AS actual_rate,
    '0-50%' AS expected
FROM readmissions;

-- Inpatient ALOS should be between 1 and 30 days (reasonable acute care range)
SELECT 
    'TEST 6.2: Inpatient ALOS is within reasonable range (1-30 days)' AS test_name,
    CASE WHEN AVG(EXTRACT(EPOCH FROM (stop - start))/86400.0) BETWEEN 1 AND 30 
         THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    ROUND(AVG(EXTRACT(EPOCH FROM (stop - start))/86400.0)::numeric, 2) AS actual_alos_days,
    '1-30 days' AS expected
FROM encounters
WHERE encounterclass = 'inpatient' AND stop IS NOT NULL;

-- DBN rate should be 0-100%
SELECT 
    'TEST 6.3: DBN rate is within 0-100%' AS test_name,
    CASE WHEN (100.0 * SUM(CASE WHEN EXTRACT(HOUR FROM stop) < 12 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)) BETWEEN 0 AND 100
         THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    ROUND((100.0 * SUM(CASE WHEN EXTRACT(HOUR FROM stop) < 12 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0))::numeric, 2) AS actual_rate,
    '0-100%' AS expected
FROM encounters
WHERE encounterclass = 'inpatient' AND stop IS NOT NULL;

-- At least some demographic diversity present
SELECT 
    'TEST 6.4: At least 3 distinct race values present' AS test_name,
    CASE WHEN COUNT(DISTINCT race) >= 3 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    COUNT(DISTINCT race) AS distinct_races,
    '>= 3 races' AS expected
FROM patients;

\echo ''
\echo '============================================================'
\echo '✅ TEST SUITE COMPLETE'
\echo '============================================================'
