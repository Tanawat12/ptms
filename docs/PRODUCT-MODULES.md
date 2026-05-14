# PTMS — Product Modules & Pricing

**Date:** 2026-05-14
**Status:** Locked with Tanawat

This document defines the **modular product architecture** for PTMS. Each module can be enabled/disabled per tenant. Customers pay for what they use. Land-and-expand revenue model.

---

## Product hierarchy

```
PTMS Platform
│
├─ 🏠 PTMS Core (always on, base price)
│   ├─ Employees + Subcontract Workers (integrated)
│   ├─ Org structure + positions + cost centers
│   ├─ Work Instructions (full builder: Pre/Tasks/Post/PPE/Tools/Defects/Tests)
│   ├─ Skill Matrix with RAD 3-level scale
│   ├─ OJA Engine (Visits → Assessments → Observations) ⭐
│   ├─ Training Records (multi-trainee, evidence)
│   ├─ Defects Log
│   ├─ PPE Issuance Log
│   ├─ Subcontract Agency Management
│   ├─ Subcontract Request Workflow (BMRequest)
│   ├─ Subcontract Attendance
│   ├─ Bilingual EN/TH
│   ├─ Audit Log
│   ├─ Reports (PDF + Excel export)
│   └─ Mobile-responsive PWA
│
├─ 🎯 Recruitment Module (add-on)
│   ├─ Hiring Manager directory
│   ├─ Staff Requisitions
│   ├─ Candidate Pool
│   ├─ Source Tracking (LinkedIn, JobsDB, walk-in, etc.)
│   ├─ Application Pipeline
│   ├─ Interview Stages (Phone → 1st → 2nd → HM Review → Reference Check)
│   ├─ Job Offers (Make, Negotiate, Accept, Decline)
│   ├─ Candidate-to-Role Matching
│   ├─ Recruitment Progression Tracking
│   ├─ Onboarding Checklist
│   └─ Recruitment Metrics & Lead Times
│
├─ 📈 Career Development Module (add-on)
│   ├─ Job Description Library (with versioning)
│   ├─ Job Competency Catalog (per JD)
│   ├─ Key Responsibility Catalog (per JD)
│   ├─ Managerial Competency Catalog (Novice/Competent/Expert)
│   ├─ Annual JD Assessment (6 dimensions: Purpose/JC/KR/CS/LC/LP)
│   ├─ "Close the Gap" Development Plans
│   ├─ Follow-up Cycle Tracking
│   ├─ Career Progression History
│   ├─ Position Succession Planning
│   ├─ Subordinate Position Mapping
│   └─ Annual Cycle Configuration
│
├─ 👥 HR Operations Module (add-on)
│   ├─ Resignation Workflow (with/without replacement)
│   ├─ Transfer Workflow (multi-step approval)
│   ├─ Replacement Tracking
│   ├─ Probation Management
│   ├─ HR Forms Catalog (94+ forms)
│   ├─ HR Policies Catalog (with versioning)
│   ├─ Employee Self-service Documents
│   └─ Multi-step Approval Chains
│
├─ 📊 Advanced Analytics Module (add-on)
│   ├─ Custom Report Builder
│   ├─ Real-time BI Dashboards
│   ├─ AI Insights (skill gap predictions, retention risk)
│   ├─ Scheduled Email Reports
│   ├─ Pareto Charts (defect analysis)
│   ├─ Skill Heatmaps
│   └─ Export to Excel/Power BI/Tableau
│
└─ 🔧 Operations Module (add-on, v3+)
    ├─ Manpower Planning
    ├─ Project (Kaizen) Tracking
    ├─ Production Floor Visualization
    ├─ Time Clock Integration
    └─ Shift Planning
```

---

## Pricing tiers

All prices in **THB / worker / month** (workers = employees + active subcontract).

| Module | Price per worker | Notes |
|---|---|---|
| 🏠 **PTMS Core** | **99 THB** | Mandatory base |
| 🎯 Recruitment Module | +30 THB | Add-on |
| 📈 Career Development Module | +40 THB | Add-on |
| 👥 HR Operations Module | +20 THB | Add-on |
| 📊 Advanced Analytics Module | +25 THB | Add-on |
| 🔧 Operations Module | +20 THB | Add-on (future) |

**Volume discounts:**
- 500-1,499 workers: -10% on all modules
- 1,500-2,999 workers: -15% on all modules
- 3,000+ workers: Custom enterprise pricing + SSO + dedicated support

**Annual prepay:** -10% (2 months free)
**Multi-year commitment** (3 years): -20% upfront

---

## Pricing examples

### Example 1: Small factory (250 workers, PTMS Core only)
- 250 × 99 THB = **24,750 THB/month**
- Annual: 297,000 THB (~$9,000 USD)
- Annual prepay: 267,300 THB (~$8,100 USD)

### Example 2: Medium factory (1,000 workers, Core + Recruitment + Career Dev)
- Per worker: 99 + 30 + 40 = 169 THB
- Volume discount: 169 × 0.9 = 152 THB
- 1,000 × 152 = **152,000 THB/month**
- Annual: 1,824,000 THB (~$55,000 USD)
- Annual prepay: 1,641,600 THB (~$50,000 USD)

### Example 3: Large factory (2,500 workers, all modules)
- Per worker: 99 + 30 + 40 + 20 + 25 = 214 THB
- Volume discount: 214 × 0.85 = 182 THB
- 2,500 × 182 = **455,000 THB/month**
- Annual: 5,460,000 THB (~$166,000 USD)
- Annual prepay: 4,914,000 THB (~$149,000 USD)

### Example 4: Enterprise (MEYERCAP, 5,000 workers, all modules + SSO)
- Custom contract, but rough math:
- Per worker: 214 × 0.80 = 171 THB
- 5,000 × 171 = **855,000 THB/month**
- Annual: 10,260,000 THB (~$310,000 USD)

---

## Revenue projections

### Target: First year
- 3 customers × 500 workers avg × 99 THB (PTMS Core only)
- = **148,500 THB/month MRR** (~$4,500 USD)
- Annual: 1.78M THB (~$54K USD)
- **Goal: Break even on dev cost**

### Target: Year 2
- 10 customers × 800 workers avg × 130 THB (Core + 1 add-on)
- = **1,040,000 THB/month MRR** (~$31,500 USD)
- Annual: 12.5M THB (~$378K USD)
- **Goal: Hire 1 Thai developer**

### Target: Year 3
- 25 customers × 1,000 workers avg × 170 THB (Core + 2-3 add-ons)
- = **4,250,000 THB/month MRR** (~$129K USD)
- Annual: 51M THB (~$1.5M USD)
- **Goal: Hire customer success + sales**

### Year 5 stretch
- 100 customers × 1,500 workers avg × 200 THB
- = **30M THB/month MRR** (~$910K USD)
- Annual: 360M THB (~$11M USD)
- **Goal: Series A or profitability**

---

## Land-and-expand strategy

**Why this works:**
1. **Low entry barrier**: 99 THB/worker is cheaper than most LMS platforms
2. **High value retention**: Once skill matrix is in production, switching cost is HUGE (years of data)
3. **Natural expansion**: After 6 months of PTMS Core, customers want Career Dev. After 12 months, they want Recruitment.
4. **Pricing power**: Module bundles are 25-40% margin uplift per customer

**Pricing levers we can pull:**
- Free trial: 30 days, no credit card
- Pilot pricing: 50% off year 1 for first 5 paying customers
- Reference customer: Free upgrade to next tier for being a case study
- Referral: 1 month free for every successful referral

---

## How module licensing works technically

Each tenant has a `modules_enabled` JSONB field:
```json
{
  "core": true,
  "recruitment": false,
  "career_dev": false,
  "hr_ops": false,
  "analytics": false,
  "operations": false
}
```

**Enforcement:**
- App-level: Sidebar hides modules that aren't enabled
- API-level: Endpoints return 403 for disabled modules
- DB-level: RLS policies check `tenant_modules` before allowing access to module-specific tables

**Upgrade flow:**
- Customer clicks "Enable Recruitment" in Settings
- Stripe charges prorated amount
- Module flips to enabled instantly
- New sidebar items appear
- Welcome modal explains the new module

---

## Beta launch plan

### Beta cohort (first 5 customers)
- **MEYERCAP** (design partner) — free for 12 months, then full price
- 4 other factories — 50% off year 1
- All beta customers get a permanent 20% loyalty discount

### Beta criteria
- 300+ workers
- Thai or English-speaking
- Willing to give weekly feedback for 3 months
- One factory floor walkthrough with Tanawat

---

## Module roadmap

| Quarter | Module | Status |
|---|---|---|
| Q3 2026 | PTMS Core | 🚧 In dev |
| Q4 2026 | PTMS Core | 🚀 Beta launch |
| Q1 2027 | PTMS Core | 🚀 Public launch |
| Q2 2027 | HR Operations Module | 🚧 In dev |
| Q3 2027 | Recruitment Module | 🚧 In dev |
| Q4 2027 | Career Development Module | 🚧 In dev |
| Q1 2028 | Advanced Analytics | 🚧 In dev |
| Q2 2028 | Operations Module | 🚧 In dev |

---

## Locked decisions

| Decision | Status |
|---|---|
| PTMS Core = mandatory base | ✅ Locked |
| Subcontract workers = integrated into Core | ✅ Locked |
| Add-on modules = separately priced | ✅ Locked |
| Per-active-worker pricing | ✅ Locked |
| Base price: 99 THB/worker/month | ✅ Locked |
| Modular architecture from day 1 | ✅ Locked |
| Free trial: 30 days | ✅ Locked |
| Annual prepay: 10% off | ✅ Locked |

---

**This is the product strategy. v1 = PTMS Core only. Add-ons follow as the business grows.**
