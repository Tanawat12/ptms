# PTMS Prototype — Walkthrough & Feedback

**URL:** https://ptms-vert.vercel.app
**Date started:** 2026-05-12

## How to use this doc

1. Open the prototype, log in (any email/password works — it's mock)
2. Use the **ROLE switcher** in the top bar to jump between roles
3. For each screen below, fill in the feedback column:
   - ✅ = looks good, ship it
   - ✏️ = needs changes (write what)
   - ➕ = missing something (write what)
   - ❌ = remove / not needed
4. When done, paste this back to me and we plan Phase 2

---

## 1) Super Owner (Tanawat — you, the platform operator)

This is YOU running the SaaS. You see all client tenants, billing, system health.

| Screen | Path | Feedback |
|---|---|---|
| Overview | `owner.dashboard` | |
| Client tenants | `owner.clients` | |
| Billing & MRR | `owner.billing` | |
| System health | `owner.health` | |
| Owner audit log | `owner.audit` | |
| Settings | `owner.settings` | |

**Questions to think about as Super Owner:**
- What metrics do YOU need to see daily to run this business?
- How do you onboard a new client (factory) — does the flow make sense?
- What pricing tiers do you want? (per-user? per-factory? flat?)

---

## 2) Client Admin (Apinya — manages one factory)

This is your customer's IT/HR admin. They set up the org, invite users, configure roles.

| Screen | Path | Feedback |
|---|---|---|
| Dashboard | `admin.dashboard` | |
| Organization (tree) | `admin.org` | |
| Users | `admin.users` | |
| Roles & access | `admin.roles` | |
| Audit log | `admin.audit` | |
| Employees | `hr.employees` | |
| Subcontractors | `hr.subcontract` | |
| Work Instructions | `training.wi` | |
| Skill matrix | `training.skills` | |
| Expiry alerts | `training.expiry` | |
| Reports & exports | `reports` | |

**Questions to think about as Client Admin:**
- Is the org tree flexible enough? (Plant → Dept → Line → Cell?)
- Can you bulk-import employees? (Excel/CSV?)
- What permissions matter most to your real customers?

---

## 3) On Job Trainer (Pailin — certifies workers)

| Screen | Path | Feedback |
|---|---|---|
| Today | `trainer.dashboard` | |
| Work Instructions | `training.wi` | |
| Skill matrix | `training.skills` | |
| Expiry alerts | `training.expiry` | |
| Defects log | `quality.defects` | |
| Trainees | `hr.employees` | |

**Questions to think about as Trainer:**
- Click a cell in the Skill matrix — does the certify flow make sense?
- When a worker is certified on a WI, what evidence do you need? (Photo? Signature? Quiz?)
- Re-certification interval — fixed per WI, or per worker?

---

## 4) Quality Lead (Pisal — defects & quality)

| Screen | Path | Feedback |
|---|---|---|
| Dashboard | `quality.dashboard` | |
| Defects log | `quality.defects` | |
| Work Instructions | `training.wi` | |
| Skill matrix | `training.skills` | |
| Reports | `reports` | |

**Questions:**
- Defects log — what fields are missing? (8D? root cause? CAPA?)
- Link defects to operators? to WI versions? to shifts?

---

## 5) Safety Lead (Suchart — PPE & incidents)

| Screen | Path | Feedback |
|---|---|---|
| Dashboard | `safety.dashboard` | |
| PPE log | `safety.ppe` | |
| Work Instructions | `training.wi` | |
| Incidents | `safety.incidents` | |
| Reports | `reports` | |

**Questions:**
- PPE issuance — track per item or per worker?
- Incident reporting — near-miss vs accident vs LTI?

---

## 6) Employee (Niran — the worker)

| Screen | Path | Feedback |
|---|---|---|
| My record | `me.home` | |
| My skills | `me.skills` | |
| Training due | `me.training` | |
| Documents | `me.documents` | |

**Questions:**
- Will workers use phone or shared tablet?
- Do they need to sign acknowledgements digitally?
- Language — Thai only? Thai + English? Per-tenant config?

---

## Cross-cutting questions (answer once)

1. **Language:** Thai, English, or both selectable?
2. **Pricing model:** _______________________________
3. **Target customer size:** Small (50-200 workers)? Medium (200-1000)? Large (1000+)?
4. **First paying customer in mind?** _______________________________
5. **Must-have integrations:** Line? Email? Excel export? Existing HR system?
6. **Hardware in factory:** Tablets? Shared PC? Workers' phones?
7. **Offline support needed?** (Factory floor often has bad WiFi)

---

## Top 3 things I'd change after the walkthrough

1. _______________________________
2. _______________________________
3. _______________________________

## Top 3 things I'd add

1. _______________________________
2. _______________________________
3. _______________________________
