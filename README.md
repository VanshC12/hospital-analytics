# 🏥 Hospital Analytics Platform

> **Production-grade healthcare quality analytics built on synthetic Epic-style EHR data, mirroring the exact workflows used at top US hospitals (Cedars-Sinai, UCLA Health, Stanford, Mayo Clinic).**

## 📊 What This Project Demonstrates

A complete healthcare data analytics environment that replicates real hospital quality reporting workflows. Built in PostgreSQL using **Synthea** synthetic patient data — the same tool MITRE, Mayo Clinic, and Stanford use for healthcare research and EHR system testing.

This project demonstrates the full stack of a hospital data analyst role:
- **Production database design** mirroring real EHR structure (FHIR-compatible)
- **CMS-compliant SQL queries** for HRRP, HEI, OP-18, NHSN, and HCAHPS workflows
- **Health equity analytics** stratifying outcomes by race, ethnicity, and gender
- **Operational KPIs** that hospital nursing directors track daily

## 🎯 The Data

- **1,103 synthetic California patients** generated via Synthea
- **1,013,610 rows** of realistic EHR data across 9 relational tables
- **705,965 clinical observations** (vitals, labs, measurements)
- **160,549 procedures** | **58,123 encounters** | **46,555 medication records**
- **37,022 diagnoses** | **2,070 providers** | **2,070 organizations**
- Full California demographic distribution (race, ethnicity, language, gender)

## 🛠️ Tech Stack

- **PostgreSQL 16** — production-grade relational database
- **Synthea** — open-source synthetic patient generator (used by Mayo Clinic, MITRE, Stanford)
- **SQL (CTEs, Window Functions, Percentile Aggregates)** — production-grade query patterns
- **Python** *(coming next)* — for ML model and data validation
- **Tableau Public** *(coming next)* — for dashboard visualization

## 📋 The Queries

All 10 queries are production-grade SQL that mirror real hospital quality team workflows:

| # | Query | Purpose | CMS Program |
|---|---|---|---|
| 1 | Demographics Breakdown | Population stratification | Health Equity Index |
| 2 | Encounter Operations | Volume, cost, LOS by encounter class | Operational reporting |
| 3 | **30-Day Readmission Rate** | HRRP penalty calculation | HRRP |
| 4 | **Readmission by Demographics** | Health equity disparity analysis | Health Equity Index |
| 5 | **Length of Stay by Service** | Operational efficiency benchmarking | Internal QI |
| 6 | **Mortality Index (O/E ratio)** | Quality flagship metric | Star Rating |
| 7 | **ED Throughput** | Median time from arrival to departure | OP-18 |
| 8 | **HAI Surveillance** | CLABSI/CAUTI/SSI/Sepsis tracking | NHSN / HAC |
| 9 | **Patient Experience Continuity** | HCAHPS leading indicator | HCAHPS / VBP |
| 10 | **Discharge Before Noon** | Throughput KPI | Internal QI |

## 🔬 Sample Findings

Running these queries on the synthetic dataset surfaced realistic hospital quality patterns:

- **17.78% 30-day readmission rate** — above the CMS HRRP penalty threshold of ~17%
- **4x readmission disparity** between demographic groups (Asian Hispanic 63% vs White Hispanic 5.6%) — exactly the kind of finding the CMS Health Equity Index is designed to surface
- **Inpatient ALOS of 4.19 days** — at the US national average
- **Mortality Index O/E of 1.78 in 18-44 age band** — would trigger case-by-case mortality review at any hospital
- **ED median LOS of 60 minutes** (CMS OP-18 measure)
- **DBN rate of 54.85%** with a Thursday throughput dip (avg discharge hour 11.3) — the kind of weekly pattern operations teams investigate

## 🏥 Why This Matters

Real hospital data analysts at Cedars-Sinai, UCLA Health, Stanford, and Mayo Clinic spend their days writing exactly these kinds of queries against Epic Clarity and Caboodle data warehouses. Every query in this repo mirrors a real CMS quality program or operational KPI:

- **HRRP** (Hospital Readmissions Reduction Program) — up to 3% Medicare payment penalty
- **HAC Reduction Program** — 1% penalty for bottom-quartile hospitals on hospital-acquired conditions
- **HCAHPS / VBP** (Value-Based Purchasing) — 2% of Medicare payments tied to patient experience
- **CMS Health Equity Index** — new 2024 reporting requirement
- **OP-18** — public ED throughput measure
- **NHSN** (National Healthcare Safety Network) — federal HAI surveillance

## 🚀 Coming Next

- [ ] Tableau Public dashboard with executive, equity, and value-based care views
- [ ] Readmission risk prediction model (Python + scikit-learn + SHAP)
- [ ] Fairness audit across demographic subgroups
- [ ] Loom video walkthrough

## 👨‍💻 Built By

**Vansh Chanchlani** — MS Analytics, University of Southern California (May 2026)

Previously analytics consultant at Los Angeles General Medical Center, a Level 1 trauma center, where I delivered $2M+ in projected annual savings through CT scanner capacity optimization using SARIMA forecasting, discrete event simulation, and Lean Six Sigma DMAIC methodology.

This project is my attempt to replicate the production analytics environment of a top US hospital and demonstrate fluency in the queries, metrics, and CMS programs that hospital data analysts work with daily.

- 🔗 [LinkedIn](https://www.linkedin.com/in/vansh-chanchlani-402bb8224)
- 📧 vanshc46in@gmail.com

## 📝 Data Disclaimer

All patient data is **synthetic, generated by Synthea**, and contains zero PHI. Synthea is an open-source synthetic patient generator created by MITRE Corporation and used by Mayo Clinic, Stanford, and major academic medical centers for healthcare research and EHR testing. https://synthetichealth.github.io/synthea/

## 📄 License

MIT License — feel free to build on this work.
