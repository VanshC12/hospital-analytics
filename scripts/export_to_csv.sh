#!/bin/bash
# Export SQL query results to CSV for Tableau dashboard

DB="hospital_analytics"
OUTPUT_DIR="tableau_data"

echo "🏥 Exporting query results for Tableau dashboard..."

echo "Exporting demographics..."
psql $DB -c "\COPY (
  SELECT race, ethnicity, gender, COUNT(*) AS patients
  FROM patients
  GROUP BY race, ethnicity, gender
) TO '$OUTPUT_DIR/demographics.csv' CSV HEADER"

echo "Exporting encounter operations..."
psql $DB -c "\COPY (
  SELECT encounterclass AS service_line, COUNT(*) AS encounters,
    ROUND(AVG(EXTRACT(EPOCH FROM (stop - start))/3600)::numeric, 2) AS avg_hours,
    ROUND(AVG(total_claim_cost)::numeric, 2) AS avg_cost
  FROM encounters WHERE stop IS NOT NULL
  GROUP BY encounterclass
) TO '$OUTPUT_DIR/encounter_ops.csv' CSV HEADER"

echo "Exporting readmissions by demographics..."
psql $DB -c "\COPY (
  WITH inpatient_stays AS (
    SELECT e.id AS encounter_id, e.patient, e.start AS admission_date, e.stop AS discharge_date,
           p.race, p.ethnicity, p.gender
    FROM encounters e JOIN patients p ON e.patient = p.id
    WHERE e.encounterclass = 'inpatient' AND e.stop IS NOT NULL
  ),
  flagged AS (
    SELECT i1.*, CASE WHEN i2.encounter_id IS NOT NULL THEN 1 ELSE 0 END AS is_readmitted
    FROM inpatient_stays i1
    LEFT JOIN inpatient_stays i2 ON i1.patient = i2.patient
      AND i2.admission_date > i1.discharge_date
      AND i2.admission_date <= i1.discharge_date + INTERVAL '30 days'
  )
  SELECT race, ethnicity, gender, COUNT(*) AS total_admissions,
    SUM(is_readmitted) AS readmissions,
    ROUND(100.0 * SUM(is_readmitted) / NULLIF(COUNT(*), 0), 2) AS readmission_rate_pct
  FROM flagged GROUP BY race, ethnicity, gender
) TO '$OUTPUT_DIR/readmissions_by_demo.csv' CSV HEADER"

echo "Exporting length of stay..."
psql $DB -c "\COPY (
  SELECT encounterclass AS service_line, COUNT(*) AS total_stays,
    ROUND(AVG(EXTRACT(EPOCH FROM (stop - start))/86400.0)::numeric, 2) AS avg_los_days,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (stop - start))/86400.0)::numeric, 2) AS median_los_days,
    ROUND(AVG(total_claim_cost)::numeric, 2) AS avg_cost_per_stay
  FROM encounters
  WHERE encounterclass IN ('inpatient', 'emergency', 'snf', 'hospice')
    AND stop IS NOT NULL AND stop > start
  GROUP BY encounterclass
) TO '$OUTPUT_DIR/length_of_stay.csv' CSV HEADER"

echo "Exporting mortality index..."
psql $DB -c "\COPY (
  WITH ip_cohort AS (
    SELECT e.id,
      CASE 
        WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 45 THEN '18-44'
        WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 65 THEN '45-64'
        WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 75 THEN '65-74'
        WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 85 THEN '75-84'
        ELSE '85+'
      END AS age_band,
      CASE WHEN p.deathdate IS NOT NULL 
        AND p.deathdate BETWEEN e.start::date AND (e.start + INTERVAL '30 days')::date
        THEN 1 ELSE 0 END AS died_30d,
      CASE 
        WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 45 THEN 0.005
        WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 65 THEN 0.020
        WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 75 THEN 0.045
        WHEN EXTRACT(YEAR FROM AGE(e.start, p.birthdate)) < 85 THEN 0.085
        ELSE 0.150
      END AS expected_rate
    FROM encounters e JOIN patients p ON e.patient = p.id
    WHERE e.encounterclass = 'inpatient'
  )
  SELECT age_band, COUNT(*) AS total_admissions,
    SUM(died_30d) AS observed_deaths,
    ROUND(SUM(expected_rate)::numeric, 2) AS expected_deaths,
    ROUND((SUM(died_30d)::numeric / NULLIF(SUM(expected_rate), 0))::numeric, 3) AS oe_ratio
  FROM ip_cohort GROUP BY age_band ORDER BY age_band
) TO '$OUTPUT_DIR/mortality_index.csv' CSV HEADER"

echo "Exporting DBN rates..."
psql $DB -c "\COPY (
  SELECT 
    CASE EXTRACT(DOW FROM stop)
      WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday'
      WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday' WHEN 6 THEN 'Saturday'
    END AS day_of_week,
    EXTRACT(DOW FROM stop)::int AS sort_order,
    COUNT(*) AS total_discharges,
    SUM(CASE WHEN EXTRACT(HOUR FROM stop) < 12 THEN 1 ELSE 0 END) AS dbn_count,
    ROUND(100.0 * SUM(CASE WHEN EXTRACT(HOUR FROM stop) < 12 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS dbn_rate_pct
  FROM encounters
  WHERE encounterclass = 'inpatient' AND stop IS NOT NULL
  GROUP BY EXTRACT(DOW FROM stop)
) TO '$OUTPUT_DIR/dbn_by_day.csv' CSV HEADER"

echo "Exporting HAI rates..."
psql $DB -c "\COPY (
  WITH ip_days AS (
    SELECT SUM(EXTRACT(EPOCH FROM (stop - start))/86400.0) AS total_days
    FROM encounters WHERE encounterclass = 'inpatient' AND stop IS NOT NULL
  )
  SELECT 
    CASE
      WHEN LOWER(description) LIKE '%sepsis%' THEN 'Sepsis'
      WHEN LOWER(description) LIKE '%urinary%infection%' OR LOWER(description) LIKE '%uti%' THEN 'UTI (CAUTI)'
      WHEN LOWER(description) LIKE '%pneumonia%' THEN 'Pneumonia (HAP/VAP)'
      WHEN LOWER(description) LIKE '%bloodstream%' OR LOWER(description) LIKE '%bacteremia%' THEN 'BSI (CLABSI)'
      WHEN LOWER(description) LIKE '%wound infection%' OR LOWER(description) LIKE '%surgical site%' THEN 'SSI'
      WHEN LOWER(description) LIKE '%difficile%' THEN 'C. diff'
      ELSE 'Other Infection'
    END AS hai_category,
    COUNT(DISTINCT patient) AS unique_patients,
    COUNT(*) AS episodes,
    ROUND((1000.0 * COUNT(*)::numeric / NULLIF((SELECT total_days FROM ip_days), 0))::numeric, 2) AS rate_per_1000_days
  FROM conditions
  WHERE LOWER(description) ~ '(infection|sepsis|pneumonia|bacteremia|cellulitis|abscess|difficile)'
  GROUP BY 1 ORDER BY episodes DESC
) TO '$OUTPUT_DIR/hai_surveillance.csv' CSV HEADER"

echo "Exporting raw patients..."
psql $DB -c "\COPY (
  SELECT id, birthdate, deathdate, race, ethnicity, gender, city, county, zip,
    EXTRACT(YEAR FROM AGE(COALESCE(deathdate, CURRENT_DATE), birthdate)) AS age,
    healthcare_expenses, healthcare_coverage, income
  FROM patients
) TO '$OUTPUT_DIR/patients.csv' CSV HEADER"

echo "Exporting raw encounters..."
psql $DB -c "\COPY (
  SELECT id, start, stop, patient, encounterclass,
    EXTRACT(EPOCH FROM (stop - start))/86400.0 AS los_days,
    total_claim_cost,
    EXTRACT(YEAR FROM start) AS year,
    EXTRACT(MONTH FROM start) AS month
  FROM encounters WHERE stop IS NOT NULL
) TO '$OUTPUT_DIR/encounters.csv' CSV HEADER"

echo ""
echo "✅ Export complete!"
ls -lh $OUTPUT_DIR/
