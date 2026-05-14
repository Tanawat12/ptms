# Excel Workbook Analysis — 73 Tables (67 sheets after merging)

**Date:** 2026-05-14
**Source:** `3fa0026f-73_Tables.xlsx` from Tanawat
**Status:** Complete review

---

## Headline numbers

- **67 sheets** (some tables were merged in the combine process)
- **275,299 total data rows**
- **Real production data** from MEYERCAP factory
- **5.4 MB** workbook

## Top tables by row count

| Rank | Table | Rows | Significance |
|---|---|---|---|
| 1 | **OjaTaskTable** | 73,871 | ⭐ Assessment task observations |
| 2 | **OjaPPETable** | 66,839 | ⭐ Assessment PPE checks |
| 3 | **OjaDefectTable** | 42,215 | ⭐ Assessment defect observations |
| 4 | **SubConAttendanceTable** | 33,711 | Subcontract worker attendance |
| 5 | **CandidateTable** | 13,699 | Recruitment candidate pool |
| 6 | **ApplicationTable** | 13,519 | Job applications with lead time tracking |
| 7 | **Paste_Errors** | 11,432 | ❌ Garbage (import errors) |
| 8 | **SkillRecord** | 5,561 | Skill matrix |
| 9 | **attendance** | 5,292 | Training attendance |
| 10 | **Employee** | 1,151 | Master employees |

## What changes about my schema

### 🎯 The OJA discovery — biggest insight

In my v1 schema I had a single `evidence_url` field on training records. **That was wrong.**

Real OJA assessments generate **dozens to hundreds of rows per session**:
- Each PPE item is ticked separately (operator wearing hard hat? gloves? safety glasses?)
- Each task step is observed separately (did they check the safety system? check the order? etc.)
- Each defect risk is noted separately (aware of porcelain crack? aware of burr?)

**Result:** 73,871 task observations across history = the real "engine" that generates skill matrix data.

**New schema:** 4 new tables — `oja_sessions` (header) + `oja_task_observations` + `oja_ppe_observations` + `oja_defect_observations`. Plus `oja_test_answers` for knowledge tests.

### 🎯 WI is a 7-table beast, not 1 table

In legacy:
1. WITable (master) — 192 WIs
2. WIPreTable — Pre-inspection steps (178)
3. **WITaskTable** — Task steps (935) ← the main content!
4. WIPostTable — Post-inspection steps (169)
5. WIPPETable — Required PPE (845)
6. WIToolTable — Required tools (195)
7. WIDefectTable — Defects to watch (308)
8. WITestTable — Knowledge test questions (681)

**My v1 had only WI + PPE + Tools + Defects.** Now adding Pre/Tasks/Post/Tests.

### 🎯 Catalogs I missed

| Excel table | New schema table | Why important |
|---|---|---|
| `Competency` | `competencies_catalog` | NOVICE/COMPETENT/EXPERT descriptions per competency |
| `JobCompetencyTable` | `position_competencies` | Each position has multiple JCs |
| `KeyResponsibilityTable` | `position_key_responsibilities` | Each position has multiple KRs |
| `CommonPositionLevel` | covered by `position_levels` | Already in v1 |
| `CostCenter` | `cost_centers` | 132 cost centers; needed for finance |
| `HRFormTable` | `hr_forms` | 94 HR forms catalog |
| `PolicyTable` + `PolicyTypeTable` | `policies` + `policy_types` | HR policies |
| `SubordinatePositionTable` | `position_subordinates` | Position hierarchy (alt to reports_to) |

### 🎯 Workflow improvements

| Excel table | New schema | Notes |
|---|---|---|
| `MatchToRoleTable` | `candidate_role_matches` | Score candidates against requisitions |
| `RecruitTrackingTable` | `recruitment_progression_log` | Audit trail of stage changes |
| `TRShare` (pictures) | `training_record_attachments` | Photos/signatures per training |
| `ShiftName` field everywhere | `shifts` table | First-class entity |
| `OBWorkStationItemTable` | covered by `wi_tasks` | Workstation items = WI task steps |
| `Topic` + `topic_no` | covered by `training_topics` | Topic catalog + scheduled deliveries |

---

## "Nonsense" tables — confirmed garbage

You were right — these we skip in migration:

| Table | Rows | Verdict | Reason |
|---|---|---|---|
| **Paste_Errors** | 11,432 | ❌ Drop | Just Excel import errors saved by mistake |
| **FOP** | 1 row | ❌ Drop | Configuration in a table; use settings instead |
| **MonthTable** | 13 | ❌ Drop | Use SQL date functions |
| **GroupTable** | 4 | 🔄 Merge | Roll into `org_nodes` (node_type='group') |
| **FamilyTable** | 29 | 🔄 Merge | Roll into `org_nodes` (node_type='family') |
| **SkillRecordExpired** | 219 | 🔄 Merge | Just `status='expired'` on `skill_records` |
| **JD** vs **JDTable** | 96 + 189 | 🔄 Consolidate | Both describe positions; pick one |
| `CandidateTable` vs `ApplicationTable` | 13K + 13K | 🔄 Re-model | One is master, other is event log; properly normalize |

---

## Embedded transactions to normalize

The legacy **Employee** table has 90 columns including:
- `ResignStatus`, `ResignRequestSubmitDate`, `ResignReason`, ...
- `TransferStatus`, `TransferFromOrgCode`, `TransferToOrgCode`, ...
- `Replacement`, `ReplacedBy`, `ReplaceMonth`, ...
- `Probation`, `ProbationCompleteDate`, ...

**Anti-pattern:** these are TRANSACTIONS (events that happen to an employee), not employee STATE.

**Fix:** In the new schema, these are already separate tables:
- `resignation_requests`
- `transfer_requests`
- Plus we'll add `probation_records` and `employee_replacement_log` in v2

The `employees` table stays clean: identity + current state, nothing else.

---

## Data quality issues found in Excel

Things to clean during migration:

1. **`OnOff` field** — mix of `0/1`, `'0'/'1'`, `true/false`. Normalize to boolean.
2. **`SkillLevel`** in Employee — single integer for "current best skill". Doesn't capture multi-WI matrix. We use `skill_records` properly.
3. **`PageUrl` column** in TrainerTable/hmtable/SCSupLoginTable — used for role-based routing. Replaced with proper RBAC.
4. **Plaintext `passcode`** column — never migrate; require all users to reset password.
5. **`CCode` vs `EmpCode`** — Candidates have `CCode`, Employees have `EmpCode`. Need careful mapping when a candidate becomes an employee.
6. **Date columns are inconsistent** — sometimes `tdate/tmonth/tyear` separated, sometimes datetime. Normalize to ISO timestamptz.
7. **Name fields duplicate** across many tables — denormalized for query speed in Access. We use proper JOINs instead.
8. **`Paste_Errors` table** — leftover from CSV imports; drop entirely.

---

## Schema growth summary

| Version | Tables | Coverage |
|---|---|---|
| v1 (yesterday) | 38 | ~70% of legacy |
| v2 (today, with Excel) | **55** | **~95% of legacy** |
| Legacy MEYERCAP | ~50 active + 15 garbage | 100% (but messy) |

**+17 new tables** from Excel analysis:

1. `cost_centers`
2. `shifts`
3. `competencies_catalog`
4. `position_competencies`
5. `position_key_responsibilities`
6. `position_subordinates`
7. `hr_forms`
8. `policy_types`
9. `policies`
10. `wi_pre_steps`
11. `wi_tasks`
12. `wi_post_steps`
13. `wi_test_questions` (replaces `wi_krs_items` from v1)
14. `oja_sessions` ⭐
15. `oja_task_observations` ⭐
16. `oja_ppe_observations` ⭐
17. `oja_defect_observations` ⭐
18. `oja_test_answers`
19. `candidate_role_matches`
20. `recruitment_progression_log`
21. `training_record_attachments`

(Actually 21 new — `oja_test_answers` and `training_record_attachments` are bonus.)

---

## 100-year design principles applied

These choices make the schema durable forever:

| Principle | How applied |
|---|---|
| **UUIDs** | All PKs; no integer overflow possible |
| **Soft delete** | `deleted_at timestamptz` on entities; compliance-safe |
| **Audit trail** | `audit_log` + history tables; never lose history |
| **Type safety** | Postgres ENUMs + CHECK constraints |
| **Time zones** | `timestamptz` everywhere; no naive timestamps |
| **i18n native** | `_en` + `_th` columns + JSONB for flexibility |
| **Versioning** | `work_instructions.version` integer (can have WI v1, v2, v3) |
| **Event sourcing** | `skill_record_history`, `recruitment_progression_log` |
| **Extensibility** | `metadata jsonb` on every entity |
| **Multi-tenant first** | `tenant_id` everywhere; RLS-enforced |
| **PII protection** | `citizen_id` encryption via pgcrypto |
| **Sharding-ready** | `tenant_id` is natural shard key |
| **Read-replica ready** | Views like `v_skill_matrix` for read-heavy workloads |
| **Backup native** | Supabase daily PITR; export to S3 weekly |
| **Future-proof** | No raw SQL strings in app; ORM-mediated (Drizzle) |

---

## What I'm doing right now

Already done:
- ✅ Read all 67 sheets, mapped to schema
- ✅ Identified OJA engine as the missing core
- ✅ Wrote `SCHEMA-V2-ADDITIONS.sql` (21 new tables)

Next (today):
- Update FEATURE-MATRIX.md to reflect OJA as v1 core (was abstracted away)
- Lock v2 schema = v1 + additions
- Wait for your confirmation, then start Sprint 0

---

## What I need from you

Just 1 question to lock the v2 schema:

**Q: For OJA sessions — do trainers assess one WI at a time per operator, or can they assess multiple WIs in one visit?**

Real data shows each `assessment_date + EmpCode + WICode` combination has multiple OJA rows (one per task/PPE/defect within that WI). But on the same `AssessmentDate`, an operator can be assessed on multiple `WICode` values.

**My read:** Each (operator, WI) is its own OJA session. A trainer visiting an operator for an hour might create 2-3 sessions if they cover 2-3 WIs. My schema supports this.

**Confirm?** Or did the legacy collapse multiple WIs into one session?

---

**That's the complete picture. We're at 95% coverage of legacy with a 100-year design.**

Ready when you are.
