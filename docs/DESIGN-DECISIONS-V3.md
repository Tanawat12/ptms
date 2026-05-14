# PTMS — Consolidated Design Decisions (v3)

**Date:** 2026-05-14
**Status:** LOCKED with Tanawat (from 9 PDFs review + Q&A doc)

This document is the **single source of truth** for design decisions. It supersedes earlier docs where they conflict.

---

## 1. Skill Level naming (LOCKED)

| Level | Symbol | Label | Meaning |
|---|---|---|---|
| **2** | 🔵 Blue circle | **INDEPENDENT** | Certified, works alone, **can be Buddy for OJT** |
| **1** | ⚫ Grey circle | **PRACTICING** | Trained, practicing, NOT yet independent |
| **0** | ⭕ Pink circle | **BEING TRAINED** | Currently being trained by Production Trainer or Buddy |
| ⭐ | Gold star | **CROSS-AREA HELPER** | Certified in OWN area, helping at this station |

Display rules:
- UI label is always full word ("BEING TRAINED" not "OJT")
- DB enum stays as `'0','1','2'` for SQL simplicity
- ⭐ star is a separate flag, not a level

---

## 2. Position hierarchy (LOCKED — fully configurable per tenant)

**Default ladder offered to new tenants** (they can edit/extend):
1. Subcontract Worker
2. Worker
3. Leader / Supervisor
4. Manager
5. Senior Manager
6. General Manager
7. Vice President (VP)
8. Executive Vice President (EVP)
9. CEO

**Implementation:**
- `position_levels` table already has `rank` (int) field
- Each tenant gets default 9 levels seeded on signup
- Tenant admin can: add levels, rename, reorder, delete unused
- No impact to core structure — just data

**Hierarchy is per-tenant, not global.**

---

## 3. "EXPECTED" KPI per WI (LOCKED)

**Definition:** Number of **Level 2 (Independent) workers** required so production runs smoothly + rotation is possible.

**Formula:** `Expected = (workers per shift) × (shifts)`
Example: 5 workers × 2 shifts = 10

**Set by:** Supervisor or On-Job Trainer for each WI
**Review cadence:** Quarterly recommended; **adjustable anytime**

**Schema change:**
```sql
alter table work_instructions
  add column expected_level_2_count int default 0,
  add column expected_review_date date,
  add column expected_last_updated_by uuid references employees(id);
```

---

## 4. ROTATION CAP formula (LOCKED)

```
Rotation Cap % = (Level 2 count) / Expected × 100
```

- **Level 1 NOT counted** (can't work independently)
- Threshold for "CAPABLE" label = **90% by default**, **configurable per tenant**
- Stored at tenant level: `tenants.rotation_cap_threshold (default 90, int)`

**Visual:**
- ≥ threshold: green "CAPABLE" / "ROTATE CAPABLE"
- < threshold: red percentage shown

---

## 5. Cross-area helpers (⭐) — NEW FEATURE

**Concept:** Worker certified in their home area (A), also trained + certified to help at a station in another area (B).

**Counted in:** Area B's skill matrix totals
**Visual indicator:** ⭐ star next to their photo / name
**No impact on:** Area A's totals (they remain certified there too)

**Schema:**
```sql
-- Already in schema, formalize:
alter table skill_records
  add column home_org_node_id uuid references org_nodes(id),
  add column workplace_org_node_id uuid references org_nodes(id),
  add column is_cross_area_helper boolean
    generated always as (home_org_node_id != workplace_org_node_id) stored;
```

When `is_cross_area_helper = true`, UI shows ⭐.

---

## 6. TR (Training Requisition) Module — v2 add-on

**TR = Training Requisition** (NOT Training Record!)

**Purpose:** Pre-approval workflow for **classroom training** (external + internal scheduled).
**NOT used for:** OJT (which is just-do-it on the floor via PTMS directly)

**Workflow:**
```
1. HR/Trainer creates TR
   ↓
2. Manager reviews → Approve/Reject
   ↓
3. Senior Manager reviews → Approve/Reject (if cost > threshold)
   ↓
4. TR PDF auto-generated, evidence stored
   ↓
5. Training session scheduled
   ↓
6. Attendees marked at training delivery
   ↓
7. Cost auto-allocated: TR.fee / attendee_count per person
   ↓
8. Each attendee's training record linked to TR
   ↓
9. Certificate auto-generated for each attendee (if applicable)
```

**Schema additions** (will add to schema v3):
```sql
create table training_requisitions (
  id uuid primary key default uuid_generate_v4(),
  tenant_id uuid not null references tenants(id),
  tr_code text not null,  -- e.g., "TR/T184362"
  title text not null,
  course_id uuid references training_topics(id),
  delivery_type text check (delivery_type in ('inhouse','public','external','elearning')),
  provider text,  -- if external
  training_fee numeric(12,2) default 0,
  expected_attendees int,
  expected_date date,
  duration_hours numeric(5,2),
  justification text,
  status text default 'draft' check (status in (
    'draft','submitted','approved_manager','approved_senior','approved_final',
    'rejected','withdrawn','completed','cancelled'
  )),
  created_by_employee_id uuid references employees(id),
  manager_decision text check (manager_decision in ('pending','approved','rejected')),
  manager_decision_by_employee_id uuid references employees(id),
  manager_decision_at timestamptz,
  manager_comment text,
  senior_decision text check (senior_decision in ('pending','approved','rejected','not_required')),
  senior_decision_by_employee_id uuid references employees(id),
  senior_decision_at timestamptz,
  senior_comment text,
  approved_pdf_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table training_records
  add column requisition_id uuid references training_requisitions(id),
  add column cost_per_attendee numeric(12,2);  -- auto = TR.fee / attendee count
```

**Module placement:** Part of **HR Operations Module** add-on, OR its own "Training Operations" sub-module.

---

## 7. Online KRS Test — v1 NEW FEATURE ⭐

**Major upgrade vs legacy:**

| Aspect | Legacy | New PTMS v1 |
|---|---|---|
| Where | Trainer-led on floor | Any device, anywhere |
| When | Only during assessment | Any time worker wants to practice |
| Format | Paper or trainer-administered | Online via personal link |
| Visibility of answers | Trainer sees | Hidden during test, shown after |

**Worker experience:**
- Get link via email/SMS/Line (e.g., `ptms.app/test/abc123xyz`)
- Open on smartphone (no login needed — link is the auth)
- See: WI name, instructions, questions one-by-one
- Submit answers
- See score + correct answers (if pass) or "Please re-take, contact trainer"
- Result auto-flows into OJA assessment as test_score

**Schema additions:**
```sql
create table krs_test_invitations (
  id uuid primary key default uuid_generate_v4(),
  tenant_id uuid not null references tenants(id),
  wi_id uuid not null references work_instructions(id),
  employee_id uuid references employees(id),
  subcontract_worker_id uuid references subcontract_workers(id),
  invite_token text unique not null,  -- random 32-char
  invite_url text generated always as ('https://ptms.app/test/' || invite_token) stored,
  expires_at timestamptz not null,
  sent_at timestamptz,
  sent_via text check (sent_via in ('email','sms','line','manual')),
  completed_at timestamptz,
  score numeric(5,2),
  passed boolean,
  created_by_employee_id uuid references employees(id),
  created_at timestamptz not null default now()
);
```

**WI page visibility (UPDATED):**
- WI detail page shows test questions + answers (study material)
- **Online test mode**: only questions + choices, answers hidden until submit

---

## 8. Auto-generated Certificates — v1 MUST HAVE

**Trigger:** Worker reaches Level 2 (Independent) on a WI

**Cert content:**
- Tenant logo + branding (color, address)
- Worker photo
- Worker name (TH + EN)
- Employee code
- WI code + name (TH + EN)
- Date certified
- Assessor name + signature image
- Cert ID (unique, verifiable)
- QR code (links to verification page on PTMS)

**Tech:**
- Generated server-side using **React PDF** or **Puppeteer**
- Stored in Supabase Storage with public read URL (verifiable)
- Auto-emailed to worker (if email on file)
- Downloadable from worker's profile

**Schema additions:**
```sql
create table certificates (
  id uuid primary key default uuid_generate_v4(),
  tenant_id uuid not null references tenants(id),
  cert_no text not null,  -- e.g., "CERT-2026-00001"
  cert_type text not null check (cert_type in ('wi_certification','training_completion','annual_assessment')),
  -- One of these
  skill_record_id uuid references skill_records(id),
  training_record_attendee_id uuid references training_record_attendees(id),
  -- Recipient
  employee_id uuid references employees(id),
  subcontract_worker_id uuid references subcontract_workers(id),
  -- Cert details
  pdf_url text not null,
  qr_code_url text,
  issued_at timestamptz not null default now(),
  issued_by_employee_id uuid references employees(id),
  -- Verification
  verification_token text unique not null,
  is_revoked boolean default false,
  revoked_at timestamptz,
  revoked_reason text
);
```

---

## 9. Department prefix codes (12, 22, 16, etc.)

**Meaning:** Meyer-internal area code naming convention only.
**For new tenants:** Use generic codes; let them define their own naming.
**Implementation:** `cost_centers.code` + `org_nodes.code` are free-text per tenant.

---

## 10. Individual Skill Record page (LOCKED layout)

**Sections:**
1. **Employee Information header**
   - Photo, Code, Name (EN + TH), Area, Position, Department, Start Date, Phone, Status
2. **Production Skills Record table**
   - WI Code | WI Name | Next Review Date | Skill Level (with circle icon) | Collaboration (OWN AREA / ⭐ Helping from OTHER)
3. **Training & Development History table**
   - No. | Course | TR No. (link) | Hours | Certificate (link) | Date
4. **Summary footer**
   - Total Classes | Total Hours | Total Cost (THB)
5. **Legend** (always visible)

**Schema:** `skill_records` already has needed fields; just need to add:
```sql
alter table skill_records
  add column next_review_date date;
```

---

## 11. UI Hierarchy (4-level drill-down — LOCKED)

```
┌──────────────────────────────────────────────────┐
│ Level 1: Company / Tenant                        │
│ "MIL WORKFORCE SKILLS INDICATOR"                 │
│ List of departments with KPI cards each          │
└──────────────────┬───────────────────────────────┘
                   ↓ click department
┌──────────────────────────────────────────────────┐
│ Level 2: Department                              │
│ "AAP - Work Stations"                            │
│ List of sub-areas with KPI cards each            │
│ Also: Department homepage with tile grid view    │
└──────────────────┬───────────────────────────────┘
                   ↓ click sub-area
┌──────────────────────────────────────────────────┐
│ Level 3: Sub-area                                │
│ "AAP - 22CT-COATING"                             │
│ List of WIs with KPI cards each                  │
│ Also: Workforce tab (workers by position)        │
└──────────────────┬───────────────────────────────┘
                   ↓ click WI
┌──────────────────────────────────────────────────┐
│ Level 4: Work Instruction Detail                 │
│ "CE80 - 12AB-ASSEMBLY-BRACKET"                   │
│ KPI cards + PPE + Tools + Pre-tasks + Tasks +    │
│ Post-tasks + Defects + Skill & Knowledge Test    │
└──────────────────────────────────────────────────┘
```

**KPI widget identical at every level:**
- WI count (or "X Work Stations")
- EXPECTED
- LEVEL 2 (INDEPENDENT)
- LEVEL 1 (PRACTICING)
- BEING TRAINED (Level 0)
- ROTATION CAP %

---

## 12. Final v1 Feature List (consolidated)

Adding/confirming for v1:
- ✅ 4-level hierarchical drill-down for Skill Matrix
- ✅ KPI widget (WI count, Expected, Levels, Rotation Cap)
- ✅ Rotation Cap with configurable threshold (default 90%)
- ✅ ⭐ Cross-area helpers
- ✅ Online KRS testing on any device
- ✅ Auto-generated certificate PDFs with QR codes
- ✅ Configurable position hierarchy per tenant
- ✅ Per-WI Expected count, adjustable by Supervisor
- ✅ Individual Skill Record page (with training history + summary)
- ✅ Sub-area workforce homepage (by position, with photos)
- ✅ Department homepage tile view
- ✅ Full WI builder with Pre/Tasks/Post/PPE/Tools/Defects/Tests
- ✅ OJA visit-based assessment engine
- ✅ Bilingual (EN/TH) throughout

Deferring to v2:
- 🔜 TR (Training Requisition) module with approval workflow
- 🔜 Recruitment module
- 🔜 Career Development (JD Assessment)
- 🔜 HR Operations (Resignation, Transfer, Policies, Forms)

---

## 13. Module placement summary

| Feature | Module |
|---|---|
| All of the above ✅ items | **PTMS Core** (99 THB/worker/month) |
| TR with approval | **HR Operations** add-on (v2) |
| Recruitment full UI | **Recruitment Module** (v2) |
| Career Dev | **Career Development Module** (v2) |
| Custom dashboards | **Advanced Analytics Module** (v3) |

---

**Locked. Ready to apply to schema + start building.**
