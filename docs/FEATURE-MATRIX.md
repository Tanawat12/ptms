# PTMS — Feature Matrix

**Date:** 2026-05-13
**Legend:**
- ✅ = Done / In scope
- 🚧 = Partially in scope (basic version)
- 🔲 = Planned for later phase
- ❌ = Out of scope (not building)
- ⭐ = High-value differentiator vs competitors

This compares: **Legacy MEYERCAP** vs **HTML prototype** vs **v1 (build now)** vs **v2 (later)**.

---

## 1. Identity, access, multi-tenancy

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Login (email/password) | ✅ (plaintext, insecure) | ✅ (mock) | ✅ (Supabase Auth) | ✅ |
| Multi-tenant SaaS | ❌ (single-org) | ❌ | ✅ ⭐ | ✅ |
| Tenant onboarding wizard | ❌ | ✅ | ✅ | ✅ |
| Role-based access (RBAC) | 🚧 (PageUrl trick) | ✅ (mock) | ✅ | ✅ |
| Custom roles per tenant | ❌ | ❌ | ✅ | ✅ |
| Granular permissions matrix | ❌ | ✅ (mock UI) | ✅ | ✅ |
| 2FA (TOTP) | ❌ | ✅ (mock) | 🔲 | ✅ |
| SSO (Google, Microsoft 365) | ❌ | ❌ | 🔲 | ✅ (Enterprise tier) |
| Audit log | ❌ | ✅ | ✅ | ✅ |
| User invite by email | ❌ | ❌ | ✅ | ✅ |
| User belongs to multiple tenants | ❌ | ❌ | ✅ | ✅ |

---

## 2. Organization structure

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Group → Family → Dept hierarchy | ✅ | ✅ | ✅ | ✅ |
| Per-tenant configurable structure | ❌ (hardcoded 16 depts) | 🚧 | ✅ ⭐ | ✅ |
| Cost centers | ✅ | 🚧 | ✅ | ✅ |
| Finance codes / payroll codes | ✅ | ❌ | ✅ | ✅ |
| Visual org chart | ❌ | ✅ (basic) | ✅ | ✅ (drag-drop edit) |
| Org change history | ❌ | ❌ | ✅ | ✅ |

---

## 3. People — Employees

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Employee directory | ✅ | ✅ | ✅ | ✅ |
| Bilingual names (EN + TH) | ✅ | ✅ | ✅ | ✅ |
| Employee photo upload | ✅ (file) | ✅ (avatar) | ✅ (Supabase Storage) | ✅ |
| Position assignment | ✅ | ✅ | ✅ | ✅ |
| Reports-to + dotted-line | ✅ | 🚧 | ✅ | ✅ |
| Employee detail (5-tab modal) | 🚧 | ✅ | ✅ | ✅ |
| Bulk import (CSV/Excel) | ❌ | ❌ | ✅ | ✅ |
| Self-service profile edit | ❌ | ✅ | ✅ | ✅ |
| Personal documents (contracts, etc.) | ❌ | ✅ (mock) | 🚧 | ✅ |
| Employee KPI tracking | ❌ | ❌ | 🔲 | ✅ |

---

## 4. People — Subcontract Workers (Bluemat) ⭐ KILLER FEATURE

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Subcontract agency directory | ✅ | ❌ | ✅ ⭐ | ✅ |
| Subcontract worker directory | ✅ | ❌ | ✅ ⭐ | ✅ |
| Worker placement (which org node) | ✅ | ❌ | ✅ | ✅ |
| Subcontract budget by org × period | ✅ | ❌ | ✅ ⭐ | ✅ |
| Subcontract request workflow (BMRequest) | ✅ | ❌ | ✅ ⭐ | ✅ |
| Subcontract attendance | ✅ | ❌ | ✅ | ✅ |
| Return-to-agency tracking | ✅ | ❌ | ✅ | ✅ |
| Agency contract management | ✅ | ❌ | 🚧 | ✅ |
| Invoice reconciliation (hours × rate) | ❌ | ❌ | 🔲 | ✅ |

**Why this matters:** Most HR/training SaaS treats subcontract workers as second-class or ignores them. In Asian manufacturing, they can be 40-60% of the workforce. **This is a moat.**

---

## 5. Training — Work Instructions

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| WI builder (multi-section) | ✅ | ✅ (8 sections) | ✅ | ✅ |
| Required PPE per WI | ✅ | ✅ | ✅ | ✅ |
| Required tools per WI | ✅ | ✅ | ✅ | ✅ |
| Defect checks per WI | ✅ | ✅ | ✅ | ✅ |
| KRS (Knowledge Review Sheet) | ✅ | 🚧 | ✅ ⭐ | ✅ |
| Cycle time tracking | ✅ | ❌ | ✅ | ✅ |
| Versioning (v1, v2, v3...) | ❌ | ❌ | ✅ | ✅ |
| Publish/archive workflow | 🚧 | ✅ | ✅ | ✅ |
| Image/video attachments | 🚧 (jpg only) | ❌ | ✅ | ✅ |
| WI templates | ❌ | ❌ | 🔲 | ✅ |
| Approval workflow before publish | ❌ | ❌ | 🔲 | ✅ |

---

## 6. Training — Skill Matrix (RAD) ⭐ CORE FEATURE

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Skill matrix (employees × WIs) | ✅ | ✅ | ✅ | ✅ |
| **RAD 3-level scale (0/1/2)** | ✅ | ❌ (yes/no) | ✅ ⭐ | ✅ |
| RAD Role Model designation | ✅ | ❌ | ✅ ⭐ | ✅ |
| Subcontract workers in matrix | ✅ | ❌ | ✅ ⭐ | ✅ |
| Click cell → certify/demote/schedule | ✅ | ✅ | ✅ | ✅ |
| Skill expiry tracking | ✅ | ✅ | ✅ | ✅ |
| Skill history (audit trail) | ❌ | ❌ | ✅ | ✅ |
| Filter by org / position / area | ✅ (many views) | ✅ | ✅ | ✅ |
| Export to Excel | ✅ | ❌ | ✅ | ✅ |
| Heatmap visualization | ❌ | ❌ | 🚧 | ✅ |
| Skill-to-pay link (compensation tier) | ✅ (RAD) | ❌ | 🔲 | ✅ |

---

## 7. Training — Records & Delivery

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Training Record (TR) entries | ✅ | 🚧 | ✅ | ✅ |
| Multi-trainee sessions (TRShare) | ✅ | ❌ | ✅ | ✅ |
| Training topics catalog | ✅ | ❌ | ✅ | ✅ |
| Trainer assignment | ✅ | ✅ | ✅ | ✅ |
| Training cost tracking | ✅ | ❌ | ✅ | ✅ |
| External vs in-house | ✅ | ❌ | ✅ | ✅ |
| Evidence upload (photos, signatures) | ❌ | ❌ | ✅ | ✅ |
| Digital signature on completion | ❌ | ❌ | 🔲 | ✅ |
| Quiz-based KRS certification | ❌ | ❌ | 🔲 | ✅ |
| LMS-style course library | ❌ | ❌ | ❌ | 🔲 |

---

## 8. Quality — Defects

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Defects log | ✅ | ✅ | ✅ | ✅ |
| Link defect → WI → operator | ✅ | ✅ | ✅ | ✅ |
| Defect severity classification | 🚧 | ✅ | ✅ | ✅ |
| Photo upload | ❌ | ❌ | ✅ | ✅ |
| Root cause / corrective action | ✅ | ✅ | ✅ | ✅ |
| 8D problem solving template | ❌ | ❌ | 🔲 | ✅ |
| CAPA (Corrective and Preventive Action) | ❌ | ❌ | 🔲 | ✅ |
| Pareto chart by defect type | ❌ | ❌ | 🔲 | ✅ |
| Defect rate trending by line/shift | ❌ | ❌ | 🚧 | ✅ |

---

## 9. Safety — PPE

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| PPE catalog | ✅ | ✅ | ✅ | ✅ |
| PPE issuance log | ✅ | ✅ | ✅ | ✅ |
| Per-employee PPE record | 🚧 | ✅ | ✅ | ✅ |
| Replacement reminders | ❌ | ❌ | ✅ | ✅ |
| Inventory levels | ❌ | ❌ | 🔲 | ✅ |
| Cost tracking | ❌ | ❌ | 🔲 | ✅ |

---

## 10. Safety — Incidents

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Incident reporting | ❌ | ✅ | 🚧 | ✅ |
| Near-miss / Accident / LTI categorization | ❌ | ✅ | 🚧 | ✅ |
| Investigation workflow | ❌ | ❌ | 🔲 | ✅ |
| OSHA / TIS-OHS report export | ❌ | ❌ | 🔲 | ✅ |

---

## 11. HR — Annual JD Assessment (6 dimensions)

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Annual cycle setup | ✅ | ❌ | ✅ | ✅ |
| **Purpose of the Role** assessment | ✅ | ❌ | ✅ | ✅ |
| **JC** (Job Competency) — NOVICE→EXPERT | ✅ | ❌ | ✅ | ✅ |
| **KR** (Key Responsibility) | ✅ | ❌ | ✅ | ✅ |
| **CS** (Computer Skill) | ✅ | ❌ | ✅ | ✅ |
| **LC** (License/Certificate) | ✅ | ❌ | ✅ | ✅ |
| **LP** (Language Proficiency) | ✅ | ❌ | ✅ | ✅ |
| "Close the Gap" development plan | ✅ | ❌ | ✅ ⭐ | ✅ |
| Follow-up cycle tracking | ✅ | ❌ | ✅ | ✅ |
| Self-review → manager → skip-level flow | 🚧 | ❌ | ✅ | ✅ |
| 360° feedback | ❌ | ❌ | ❌ | 🔲 |

---

## 12. HR — Career Progression

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Career progression history | ✅ | ❌ | ✅ | ✅ |
| Position level / grade tracking | ✅ | 🚧 | ✅ | ✅ |
| JC-based progression | ✅ | ❌ | 🚧 | ✅ |
| Succession planning | ❌ | ❌ | ❌ | 🔲 |
| 9-box talent grid | ❌ | ❌ | ❌ | 🔲 |

---

## 13. HR — Movement Workflows

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Resignation request flow | ✅ | ❌ | ✅ | ✅ |
| Resignation with/without replacement | ✅ | ❌ | ✅ | ✅ |
| Transfer request flow | ✅ | ❌ | ✅ | ✅ |
| Multi-step approval | ✅ | ❌ | ✅ | ✅ |
| Exit interview | ❌ | ❌ | 🔲 | ✅ |
| Re-hire eligibility flag | ❌ | ❌ | 🔲 | ✅ |

---

## 14. HR — Recruitment (deferred to v2)

| Feature | Legacy | Prototype | v1 (schema only) | v2 |
|---|---|---|---|---|
| Hiring manager directory | ✅ | ❌ | 🔲 | ✅ |
| Staff requisition | ✅ | ❌ | 🔲 | ✅ |
| Candidate pool / search | ✅ | ❌ | 🔲 | ✅ |
| Candidate applications | ✅ | ❌ | 🔲 | ✅ |
| Source tracking (LinkedIn, etc.) | ✅ | ❌ | 🔲 | ✅ |
| Multi-stage interview flow | ✅ | ❌ | 🔲 | ✅ |
| HR screening → phone → 1st → 2nd → HM review → ref check | ✅ | ❌ | 🔲 | ✅ |
| Job offer flow | ✅ | ❌ | 🔲 | ✅ |
| Onboarding checklist | ❌ | ❌ | ❌ | 🔲 |
| Job board widget (careers page) | ❌ | ❌ | ❌ | 🔲 |

**v1 has the database schema ready; we just don't build the UI until v2.**

---

## 15. Operations — Manpower Planning

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Manpower planning (current vs target headcount) | ✅ | ❌ | 🔲 | ✅ |
| Headcount by org / position | ✅ | ❌ | 🚧 | ✅ |
| Subcontract budget tracking | ✅ | ❌ | ✅ | ✅ |
| Resource gap analysis | ✅ | ❌ | 🔲 | ✅ |

---

## 16. Operations — Projects (Kaizen)

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Project tracking | ✅ | ❌ | 🚧 | ✅ |
| Project members | ✅ | ❌ | 🚧 | ✅ |
| Project topics + individual items | ✅ | ❌ | 🚧 | ✅ |
| Kanban board | ❌ | ❌ | ❌ | 🔲 |
| Time tracking | ❌ | ❌ | ❌ | 🔲 |

---

## 17. Reporting

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Reports library | ✅ | ✅ | ✅ | ✅ |
| Excel export | ✅ | ❌ | ✅ | ✅ |
| PDF export | ❌ | ❌ | ✅ | ✅ |
| Predefined dashboards (Trainer, Quality, Safety) | ✅ (16 hardcoded) | ✅ | ✅ | ✅ |
| Custom dashboards | ❌ | ❌ | ❌ | 🔲 |
| Custom report builder | ❌ | ❌ | ❌ | 🔲 |
| Scheduled email reports | ❌ | ❌ | 🔲 | ✅ |

---

## 18. SaaS Platform (Owner side — for you, Tanawat)

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| Owner dashboard (MRR, churn, active tenants) | ❌ | ✅ | ✅ | ✅ |
| Tenant list & detail view | ❌ | ✅ | ✅ | ✅ |
| Client onboarding wizard | ❌ | ✅ | ✅ | ✅ |
| Billing & invoicing (Stripe) | ❌ | ✅ (mock) | ✅ | ✅ |
| Plan management (trial, starter, pro, enterprise) | ❌ | ✅ (mock) | ✅ | ✅ |
| System health metrics | ❌ | ✅ | 🚧 | ✅ |
| Owner audit log | ❌ | ✅ | ✅ | ✅ |
| Feature flag toggle per tenant | ❌ | ❌ | ✅ | ✅ |
| Impersonate (login-as) a tenant user | ❌ | ❌ | ✅ | ✅ |

---

## 19. Platform/Infra

| Feature | Legacy | Prototype | v1 | v2 |
|---|---|---|---|---|
| HTTPS | ❌ (HTTP) | ✅ | ✅ | ✅ |
| Daily backups | ❌ (file copy) | ❌ | ✅ | ✅ |
| Monitoring (Sentry / errors) | ❌ | ❌ | ✅ | ✅ |
| Email notifications | ❌ | ❌ | ✅ | ✅ |
| Webhook outbound (to client systems) | ❌ | ❌ | 🔲 | ✅ |
| Public API | ❌ | ❌ | ❌ | 🔲 |
| Mobile app (native) | ❌ | ❌ | ❌ | 🔲 |

---

## Summary

### What's in v1 (the build-now scope)

**~70% of the legacy system's value**, modernized:
- Multi-tenant SaaS foundation
- Employees + Subcontract (Bluemat) + Agencies + Attendance
- Work Instructions + PPE + Tools + Defects + KRS
- Skill Matrix with RAD 3-level
- Training Records (multi-trainee, evidence)
- Defects log + PPE issuance log
- Annual JD Assessment (6 dimensions) + Close the Gap
- Resignation + Transfer workflows
- Reports library with Excel/PDF export
- Owner platform (SaaS metrics, tenants, billing)

### What's deferred to v2

- Recruitment full UI (schema ready)
- Career progression / talent grid
- Custom dashboards & reports
- Manpower planning
- Project (Kaizen) management beyond basic
- Native mobile app
- Public API
- Advanced i18n (beyond Thai + English)

### What we're NOT building

- LMS / course library
- Payroll
- Time clock hardware integration
- Inventory management
- Customer / order tracking
- AI features (until customers ask)

---

**This is the contract for v1. Any feature not in v1 column goes to v2 backlog. No mid-flight scope expansion.**
