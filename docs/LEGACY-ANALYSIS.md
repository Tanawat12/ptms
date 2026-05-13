# Legacy MEYERCAP System — First Analysis

**Date:** 2026-05-13
**Source:** `ptms-legacy` repo (671 ASP files)
**Status:** First-pass analysis. Deeper dive pending Excel schema files.

---

## TL;DR

The legacy system is **way bigger** than the prototype you have. It handles:
- Production training (the core)
- HR (resignation/transfer approval, recruitment, candidate tracking)
- Skill matrix + recertification
- Job description assessment (JD/JC)
- Career progression
- Project & topic management
- Subcontractor management with attendance
- PPE & defects tracking
- Per-department dashboards (16 departments hardcoded)

This is a **proper enterprise-grade factory operations app**, not just a training prototype. The new PTMS should expand to cover most of this.

---

## Tech stack (legacy)

| Layer | Technology | Notes |
|---|---|---|
| Frontend | Bootstrap 3 + jQuery + IE8 polyfills | Old, but functional |
| Server | ASP Classic (`.asp`) on IIS | Microsoft script engine, end-of-life |
| Database | **Microsoft Access** (`training.mdb`) | 197 MB single file, file-based |
| Auth | `TrainerTable` with plaintext UserName/PassCode | Insecure, SQL-injection vulnerable |
| Charset | windows-874 / tis-620 (Thai) | UI is in Thai + English |
| Photos | `/EmployeePhoto/{empcode}.jpg` | File-based storage |
| Hosting | On-premise IP `110.170.35.133` | Single tenant, single server |

**Critical security issues in legacy** (we'll fix all of these in v2):
- Plaintext passwords in DB
- Raw SQL string concatenation (e.g. `"WHERE [UserName]='"& UserName &"'"`) — fully open to SQL injection
- No HTTPS visible in code
- Login uses GET-style redirect (`PageUrl` field decides where user goes after login)

---

## Database tables discovered (from SQL queries in ASP)

### Core training tables
| Table | Purpose (inferred) |
|---|---|
| `WITable` | Work Instructions (the master training documents) |
| `WIPPETable` | PPE required per WI |
| `WIToolTable` | Tools required per WI |
| `WIDefectTable` | Defects/quality checks per WI |
| `StandardToolTable` | Master tool catalog |
| `PPETable` | Master PPE catalog |
| `SkillRecord` | Who's certified on which WI (the skill matrix) |
| `TR` | Training Records (delivery events) |
| `TRShare` | Multi-trainee training session sharing |

### People & access
| Table | Purpose |
|---|---|
| `Employee` | Master employee record (probably ~1000s of rows) |
| `TrainerTable` | Login accounts for trainers + their `PageUrl` redirect |
| `hmtable` | Possibly "HR Master" — needs verification |
| `AgencyTable` | Subcontractor agencies/vendors |
| `SubConRequest` | Subcontractor labor requests |
| `SubConAttendanceTable` | Daily attendance for subcontractors |
| `Attendance` | Employee attendance |

### HR workflows
| Table | Purpose |
|---|---|
| `ApplicationTable` | Job applications |
| `CandidateTable` | Candidate pool |
| `SourceTable` | Application source (LinkedIn, walk-in, etc.) |
| `ProgressionTable` | Career progression history |

### Job descriptions & assessment
| Table | Purpose |
|---|---|
| `JDTable` | Job descriptions (master list) |
| `JDAssessmentTable` | Annual job description assessment |
| `JCAssessmentTable` | Job competency assessment |
| `JCProgressionTable` | JC-based career progression |
| `AssessmentYearTable` | Yearly assessment cycle config |
| `RADRoleModel` | Role model designation (RAD = ?) |

### Project management
| Table | Purpose |
|---|---|
| `ProjectTable` | Projects (kaizen? improvement initiatives?) |
| `ProjectMemberTable` | Project team members |
| `ProjectTopicTable` | Topics within projects |
| `ProjectIndividualTopicTable` | Individual contribution to topics |
| `ProjectIndividualItemTable` | Individual action items |

### Bluemat (unclear — needs your input)
| Table | Purpose |
|---|---|
| `BluematBudget` | Budget for "bluemat" — blueprints? blue mat = quality checks? |
| `BMRequest` | Bluemat request workflow |

**Question for Tanawat:** What is "Bluemat"? Looks like a major module but I can't tell from the queries alone.

---

## Major user-facing workflows (from file names + entry points)

### 1. Trainer workflow (`mptslogin1.asp` → `maintrainer.asp`)
- Skill Record management (`ptsskillrecordtrainer1.asp`)
- Re-certify & Update Skill (`tgptrecertifyskill.asp`)
- On Job Assessment (login again → assessment forms)
- Production Training Report (`tgptreport.asp`)
- "We Are One" — collaboration/help feature (`tgptgethelp1.asp`)

### 2. Per-department dashboards (16 departments)
Each department has its OWN ASP file:
- `Home-Fabrication2.asp`, `Home-QA.asp`, `Home-mtn.asp`, `Home-tpm.asp`
- `HomeCs.asp`, `HomeENVIRONMENT.asp`, `HomeHSS.asp`, `HomeHr.asp`
- `HomeLABORATORY.asp`, `HomeMIS.asp`, `HomeNPD.asp`, `HomeNpi.asp`
- `HomeOven.asp`, `HomePress.asp`, `HomeSc.asp`, `Homeem.asp`

**Big anti-pattern:** Each department dashboard is a separate hardcoded file. In the new SaaS, this should be ONE dynamic dashboard configured per tenant/department.

### 3. Division Manager workflow (25 files)
Files like `dmframemenu1QA.asp`, `dmframemenu1MIS.asp`, etc. — separate menu per division.

### 4. HR workflows
- Resignation approval flow (`ApproveResign1.asp`, `2.asp`, `3.asp`)
- Resignation with no replacement (`ApproveResignNoReplace1/2.asp`)
- Transfer approval (`ApproveTransfer1/2/3.asp`)
- Candidate search & pool (`CandidateSearch.asp`, `CheckCandidate1.asp`...)
- Manpower planning (`manpower1.asp` — 92 KB, biggest file)

### 5. Skill matrix views (huge variety)
- `EmpLevelView.asp`, `EmpLevelView1.asp`
- `EmpLevelViewAll.asp`, `EmpLevelViewArea.asp`, `EmpLevelViewOrgCode.asp`
- All with `*All` variants for "show everyone" mode

### 6. WI (Work Instruction) management
- `AddNewTrainingTopic.asp` → `1.asp` → `2.asp` (multi-step wizard)
- `AddTR0.asp` → `1.asp` → `2.asp` (training record entry)
- `addppe2.asp`, `addtool2.asp` (PPE & tool management within WI)

### 7. Close-the-gap workflow (career development)
- `Closethegap1Purpose.asp`, `Closethegap1cs.asp`, `Closethegap1jc.asp`, `Closethegap1kr.asp`...
- The suffix codes (cs, jc, kr, lc, lp) look like skill domains. Need your confirmation.

### 8. Annual assessment cycle
- `annualassessmenthome.asp`
- `annualprioritizinghome.asp`

---

## Key findings for the new system design

### ✅ Keep / expand in new PTMS
1. **Work Instruction structure** — WI + PPE + Tools + Defects relationship is solid. Already in our prototype.
2. **Skill matrix (employees × WIs)** — Core feature, multiple view filters needed.
3. **Re-certification workflow** — Worth replicating.
4. **PageUrl-style routing per role** — But done properly with proper RBAC, not a DB column.
5. **Multi-tenant departments/divisions** — Replace 16 hardcoded home pages with one dynamic dashboard.
6. **Subcontractor management** — Underrated; could be a paid add-on.
7. **PPE/Defects tracking** — Already in prototype, expand.

### ❌ Modernize / replace in new PTMS
1. **MS Access** → Supabase (Postgres) with multi-tenant row-level security
2. **Plaintext passwords** → bcrypt/argon2 + Supabase Auth
3. **SQL string concatenation** → parameterized queries / ORM (Prisma or Drizzle)
4. **16 hardcoded department home pages** → 1 dynamic dashboard with per-department config
5. **25 hardcoded division menu files** → 1 sidebar menu, RBAC-driven
6. **`.jpg` file-system photos** → Supabase Storage with signed URLs
7. **Thai charset windows-874** → UTF-8 everywhere
8. **IE8 compatibility shims** → Drop, support modern browsers only
9. **Bootstrap 3** → Modern stack (we already have a clean design system in the prototype)

### 🆕 Features in legacy that AREN'T in your current prototype
These are valuable; we should add them to the new PTMS:

1. **Recruitment / candidate pool management** (CandidateTable, ApplicationTable, SourceTable)
2. **JD/JC annual assessment** (JDAssessmentTable, JCAssessmentTable, AssessmentYearTable)
3. **Career progression tracking** (ProgressionTable, JCProgressionTable)
4. **Resignation/Transfer approval workflows** (multi-step approve forms)
5. **Manpower planning** (manpower1.asp — biggest single file)
6. **Subcontractor agency + attendance** (AgencyTable, SubConAttendanceTable)
7. **Project/topic/item tracking** (kaizen-style improvement projects?)
8. **"Close the gap" career development workflow**
9. **Annual assessment cycle config**
10. **"Bluemat" — unknown but seems significant**

---

## Confirmed answers (from Tanawat)

### 1. Bluemat = Subcontract Workers (NOT what I expected!)
- Client hires a **contracting agency**; agency provides workers
- Workers paid at **minimum wage**
- Workers can be **returned to agency anytime** by client (flexible workforce)
- Critical for manufacturing flexibility (scale up/down without permanent hires)
- `BluematBudget` = budget allocation for subcontract labor
- `BMRequest` = workflow to request additional subcontract workers
- `AgencyTable` = master list of the contracting agencies
- `SubConAttendanceTable` = daily attendance for these workers
- **This is a MAJOR feature** — many factories use subcontract workers extensively

### 2. JD Assessment suffix codes = 6 categories of annual performance review
These are the **6 dimensions** of the annual Job Description (JD) assessment:

| Code | Meaning | What it measures |
|---|---|---|
| `Purpose` | Purpose of the Role | Alignment with role purpose: ALIGNED / PARTIALLY-MISALIGN / MISALIGN |
| `cs` | **Computer Skill** | Software/programs proficiency |
| `jc` | **Job Competency** | Core skills, scored: NOVICE → ADVANCED-BEGINNER → COMPETENT → PROFICIENT → EXPERT |
| `kr` | **Key Responsibility** | Job results, scored: NEED-IMPROVEMENT → MEET-EXPECTATIONS → EXCEED-EXPECTATIONS → LEADING-PERFORMANCE (or NEW-IN-ROLE if < 6 months) |
| `lc` | **License/Certificate** | Required licenses & certifications present |
| `lp` | **Language Proficiency** | Non-Thai (usually English) language ability |

Each year, every employee is assessed on all 6 dimensions → gaps identified → development plan ("Close the Gap" workflow) → tracked through follow-up cycles.

### 3. hmtable = Hiring Manager Table
Simple lookup table for recruitment process. Stores hiring manager names + info. Used by HR + hiring managers in the recruitment workflow.

### 4. RAD = "Review And Development"
The **Skills-Based Pay System** for the shop floor.

- **RAD Role Model** = designation given to skilled workers who can train others
- Tied to **KRS** (Knowledge Review Sheet) — certification per workstation
- Skill levels (0–2):
  - **Level 2** = Capable. Can work alone AND train others. (RAD Role Model qualified)
  - **Level 1** = Practicing. Still under supervision of OJT or Supervisor.
  - **Level 0** = Being trained. Full-time supervision required.
- Applies to BOTH direct employees AND subcontract (Bluemat) workers
- Drives pay decisions → skill = money

**This is a killer feature.** Many factories don't have a clear skill-pay link, and this is exactly what production managers want.

### 5. 16 departments = MEYERCAP-specific
Must be **configurable per tenant** in the new SaaS. Each client (factory) will define their own departments. No hardcoded list.

### 6. Strategy: Start with PTMS, design for expansion
- Phase 1: Sell PTMS (training + skill matrix + Bluemat + RAD)
- Phase 2+: Expand into recruitment, JD assessment, manpower planning
- **Architecture must anticipate growth** — no shortcuts that lock us into a small system

---

## What this changes about our plan

### Add to v1 of new PTMS (was: deferred)
- **Subcontractor (Bluemat) full workflow** — agency, request, attendance, budget tracking
- **RAD Skills-Based Pay levels (0/1/2)** — replace generic "certified" yes/no with this 3-level system
- **KRS (Knowledge Review Sheet)** — per-workstation certification, linked to WI

### Confirmed v2 features (later phase)
- Recruitment pipeline (HM table, candidates, applications, sources)
- JD annual assessment (Purpose + 5 dimension codes + close-the-gap workflow)
- Career progression (Progression tables)
- Resign/Transfer approval workflows
- Manpower planning

---

## Next steps

When the **73-sheet Excel workbook** arrives, I'll:
1. Map every table → confirmed schema (column names, types, sample data)
2. Build an ERD (entity-relationship diagram)
3. Design the new multi-tenant Supabase schema
4. Identify which legacy features to include in v1 vs. defer to v2

For now: **sleep well, this is excellent material to work with!** 🌙
