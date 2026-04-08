-- Load Synthea CSV data into hospital database
\set csv_path '/Users/vansh/Desktop/hospital-analytics/synthea/output/csv'

\echo 'Loading patients...'
\copy patients FROM '/Users/vansh/Desktop/hospital-analytics/synthea/output/csv/patients.csv' WITH (FORMAT csv, HEADER true);

\echo 'Loading organizations...'
\copy organizations FROM '/Users/vansh/Desktop/hospital-analytics/synthea/output/csv/organizations.csv' WITH (FORMAT csv, HEADER true);

\echo 'Loading providers...'
\copy providers FROM '/Users/vansh/Desktop/hospital-analytics/synthea/output/csv/providers.csv' WITH (FORMAT csv, HEADER true);

\echo 'Loading payers...'
\copy payers FROM '/Users/vansh/Desktop/hospital-analytics/synthea/output/csv/payers.csv' WITH (FORMAT csv, HEADER true);

\echo 'Loading encounters...'
\copy encounters FROM '/Users/vansh/Desktop/hospital-analytics/synthea/output/csv/encounters.csv' WITH (FORMAT csv, HEADER true);

\echo 'Loading conditions...'
\copy conditions FROM '/Users/vansh/Desktop/hospital-analytics/synthea/output/csv/conditions.csv' WITH (FORMAT csv, HEADER true);

\echo 'Loading medications...'
\copy medications FROM '/Users/vansh/Desktop/hospital-analytics/synthea/output/csv/medications.csv' WITH (FORMAT csv, HEADER true);

\echo 'Loading procedures...'
\copy procedures FROM '/Users/vansh/Desktop/hospital-analytics/synthea/output/csv/procedures.csv' WITH (FORMAT csv, HEADER true);

\echo 'Loading observations (this is the big one, ~1M+ rows)...'
\copy observations FROM '/Users/vansh/Desktop/hospital-analytics/synthea/output/csv/observations.csv' WITH (FORMAT csv, HEADER true);

\echo ''
\echo '============================================'
\echo 'LOAD COMPLETE - Row counts:'
\echo '============================================'

SELECT 'patients' AS table_name, COUNT(*) AS rows FROM patients
UNION ALL SELECT 'organizations', COUNT(*) FROM organizations
UNION ALL SELECT 'providers', COUNT(*) FROM providers
UNION ALL SELECT 'payers', COUNT(*) FROM payers
UNION ALL SELECT 'encounters', COUNT(*) FROM encounters
UNION ALL SELECT 'conditions', COUNT(*) FROM conditions
UNION ALL SELECT 'medications', COUNT(*) FROM medications
UNION ALL SELECT 'procedures', COUNT(*) FROM procedures
UNION ALL SELECT 'observations', COUNT(*) FROM observations
ORDER BY rows DESC;
