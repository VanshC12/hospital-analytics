DROP TABLE IF EXISTS observations CASCADE;
DROP TABLE IF EXISTS medications CASCADE;
DROP TABLE IF EXISTS procedures CASCADE;
DROP TABLE IF EXISTS conditions CASCADE;
DROP TABLE IF EXISTS encounters CASCADE;
DROP TABLE IF EXISTS providers CASCADE;
DROP TABLE IF EXISTS organizations CASCADE;
DROP TABLE IF EXISTS payers CASCADE;
DROP TABLE IF EXISTS patients CASCADE;

CREATE TABLE patients (
    id TEXT PRIMARY KEY,
    birthdate DATE,
    deathdate DATE,
    ssn TEXT,
    drivers TEXT,
    passport TEXT,
    prefix TEXT,
    first TEXT,
    middle TEXT,
    last TEXT,
    suffix TEXT,
    maiden TEXT,
    marital TEXT,
    race TEXT,
    ethnicity TEXT,
    gender TEXT,
    birthplace TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    county TEXT,
    fips TEXT,
    zip TEXT,
    lat NUMERIC,
    lon NUMERIC,
    healthcare_expenses NUMERIC,
    healthcare_coverage NUMERIC,
    income NUMERIC
);

CREATE TABLE organizations (
    id TEXT PRIMARY KEY,
    name TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    lat NUMERIC,
    lon NUMERIC,
    phone TEXT,
    revenue NUMERIC,
    utilization INTEGER
);

CREATE TABLE providers (
    id TEXT PRIMARY KEY,
    organization TEXT,
    name TEXT,
    gender TEXT,
    speciality TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    lat NUMERIC,
    lon NUMERIC,
    encounters INTEGER,
    procedures INTEGER
);

CREATE TABLE payers (
    id TEXT PRIMARY KEY,
    name TEXT,
    ownership TEXT,
    address TEXT,
    city TEXT,
    state_headquartered TEXT,
    zip TEXT,
    phone TEXT,
    amount_covered NUMERIC,
    amount_uncovered NUMERIC,
    revenue NUMERIC,
    covered_encounters INTEGER,
    uncovered_encounters INTEGER,
    covered_medications INTEGER,
    uncovered_medications INTEGER,
    covered_procedures INTEGER,
    uncovered_procedures INTEGER,
    covered_immunizations INTEGER,
    uncovered_immunizations INTEGER,
    unique_customers INTEGER,
    qols_avg NUMERIC,
    member_months INTEGER
);

CREATE TABLE encounters (
    id TEXT PRIMARY KEY,
    start TIMESTAMP,
    stop TIMESTAMP,
    patient TEXT REFERENCES patients(id),
    organization TEXT,
    provider TEXT,
    payer TEXT,
    encounterclass TEXT,
    code TEXT,
    description TEXT,
    base_encounter_cost NUMERIC,
    total_claim_cost NUMERIC,
    payer_coverage NUMERIC,
    reasoncode TEXT,
    reasondescription TEXT
);

CREATE TABLE conditions (
    start DATE,
    stop DATE,
    patient TEXT REFERENCES patients(id),
    encounter TEXT,
    system TEXT,
    code TEXT,
    description TEXT
);

CREATE TABLE medications (
    start TIMESTAMP,
    stop TIMESTAMP,
    patient TEXT REFERENCES patients(id),
    payer TEXT,
    encounter TEXT,
    code TEXT,
    description TEXT,
    base_cost NUMERIC,
    payer_coverage NUMERIC,
    dispenses INTEGER,
    totalcost NUMERIC,
    reasoncode TEXT,
    reasondescription TEXT
);

CREATE TABLE observations (
    date TIMESTAMP,
    patient TEXT REFERENCES patients(id),
    encounter TEXT,
    category TEXT,
    code TEXT,
    description TEXT,
    value TEXT,
    units TEXT,
    type TEXT
);

CREATE TABLE procedures (
    start TIMESTAMP,
    stop TIMESTAMP,
    patient TEXT REFERENCES patients(id),
    encounter TEXT,
    system TEXT,
    code TEXT,
    description TEXT,
    base_cost NUMERIC,
    reasoncode TEXT,
    reasondescription TEXT
);

CREATE INDEX idx_encounters_patient ON encounters(patient);
CREATE INDEX idx_encounters_start ON encounters(start);
CREATE INDEX idx_encounters_class ON encounters(encounterclass);
CREATE INDEX idx_conditions_patient ON conditions(patient);
CREATE INDEX idx_conditions_code ON conditions(code);
CREATE INDEX idx_observations_patient ON observations(patient);
CREATE INDEX idx_medications_patient ON medications(patient);

SELECT 'Schema created successfully!' AS status;
