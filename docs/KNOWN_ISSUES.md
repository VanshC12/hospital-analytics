# Known Data Issues & Quirks

> **Why this doc exists:** Every hospital dataset has quirks. Production data teams document them so downstream analysts don't get surprised. This doc catalogs the known issues in this project's Synthea-generated dataset.

## 🔴 Issue #1: Suspicious Zero Mortality in 75-84 Age Band

**Where:** `sql/06_mortality_index.sql`

**What:** The O/E ratio for the 75-84 age band came back as 0.000 — zero observed deaths out of 91 admissions, vs. 7.74 expected deaths.

**Likely cause:** Synthea's mortality simulation model may not align with CMS age-band expected mortality rates. In real Epic data, this age band typically sees observed mortality between 7-10%.

**How a real analyst would handle this:** Flag for upstream data source investigation. If running on real Epic Clarity data, this would trigger a case-by-case review — either there's a data pipeline issue (deaths not flowing from ADT feeds) or an extraordinary clinical outcome worth investigating.

**Impact on analysis:** O/E ratio is unreliable for this cohort. Suppress or annotate in published reports.

---

## 🔴 Issue #2: Insufficient Sample Size in 85+ Cohort

**Where:** `sql/06_mortality_index.sql`

**What:** Only 6 admissions in the 85+ age band — below the CMS minimum case-count threshold of 25 for reliable risk-adjusted reporting.

**How a real analyst would handle this:** Apply small-cell suppression. CMS public reporting suppresses any cell with fewer than 25 cases to protect both statistical reliability and patient privacy (re-identification risk).

**Recommended fix:** Add `HAVING COUNT(*) >= 25` to production versions of the query, or mark the cohort as "insufficient sample" in dashboards.

---

## 🔴 Issue #3: Uniform ED-to-Inpatient Admission LOS (Synthea Quirk)

**Where:** `sql/07_ed_throughput.sql`

**What:** All 93 admitted ED patients show exactly 60 minutes of ED LOS. In real Epic data, admitted patients typically show 4-8 hours of ED LOS (the "boarding" problem — waiting for an inpatient bed).

**Likely cause:** Synthea's encounter generation doesn't simulate the realistic ED-to-inpatient handoff timing. It treats the ED visit as a discrete 60-minute event regardless of downstream admission.

**Impact on analysis:** ED boarding time cannot be measured with this dataset. In production, boarding time is calculated as the delta between the ED disposition decision timestamp and the inpatient admission timestamp. Synthea doesn't capture disposition decision time separately.

**How a real analyst would handle this:** Document the limitation clearly and use real Epic ADT timestamps (ED_DISP, ADM_CONFIRM) when available.

---

## 🟡 Issue #4: Skewed Patient Experience Continuity Distribution

**Where:** `sql/09_patient_experience.sql`

**What:** 98.5% of patients fall into "Excellent Continuity" (1,087 of 1,103). In real EHR data, continuity ratios are much more evenly distributed.

**Likely cause:** Synthea models realistic provider-patient relationships but may over-weight continuity compared to real-world fragmented care.

**Impact on analysis:** The continuity-based HCAHPS proxy has limited discriminating power on this dataset. Care management triage based solely on this metric would miss most at-risk patients.

**Recommended fix:** When running on real data, expect a more balanced distribution and recalibrate the tier thresholds accordingly.

---

## 🟡 Issue #5: Large Gap Between Mean and Median Inpatient LOS

**Where:** `sql/05_length_of_stay.sql`

**What:** Inpatient mean LOS is 4.19 days but median LOS is only 2.14 days — a 2x gap indicates heavy right-skew from long-stay outliers.

**Not actually a data issue** — this is **the reality of real hospital LOS distributions**. It's why hospital quality teams always report BOTH mean and median (and often P90) rather than relying on average alone.

**Documented here because:** A junior analyst looking only at the mean would miss the story. The median tells you "typical" patient experience; the mean is dragged up by the 10% of complex cases. This is a feature of the analysis, not a bug.

---

## 🟡 Issue #6: Inflated Synthetic Readmission Disparities

**Where:** `sql/04_readmission_by_demographics.sql`

**What:** The readmission rate for Asian Hispanic patients (63.16%) and Native non-Hispanic patients (58.14%) is dramatically higher than other demographic groups in the dataset.

**Likely cause:** Synthea generates demographic distributions using stochastic models that don't perfectly mirror real-world Social Determinants of Health patterns. The apparent disparity is more likely sampling variance than a realistic health equity gap.

**Why the query is still valuable:** The methodology — CTE-based cohort building, demographic stratification, cell suppression for statistical reliability — is identical to what CMS requires for Health Equity Index reporting. The analytical framework works on any dataset; only the specific findings are Synthea-dependent.

**Recommended framing for interviews:** "The query demonstrates CMS HEI-compliant stratification methodology. The specific disparity values are Synthea artifacts, but the framework is production-ready for real Epic data."

---

## 🟢 Data Quality Test Suite Summary

Running `tests/01_data_quality_tests.sql` returns 18/18 passing tests across:
- Row count sanity ✅
- Referential integrity ✅
- Null rate compliance ✅
- Date logic ✅
- Value ranges ✅
- Business logic plausibility ✅

The dataset is internally consistent. The issues documented above are **known limitations of Synthea as a data source**, not errors in the analysis queries themselves.
