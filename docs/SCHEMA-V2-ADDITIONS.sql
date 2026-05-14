-- ============================================================================
-- PTMS v1 — SCHEMA V2 ADDITIONS
-- ============================================================================
-- Date:    2026-05-14
-- Purpose: Additions to NEW-SCHEMA.sql after analyzing Tanawat's 67-sheet
--          Excel data (275K rows of real production data).
--
-- This file APPENDS new tables to NEW-SCHEMA.sql. Apply NEW-SCHEMA.sql first,
-- then this file. Or merge them later for v2.
--
-- WHAT'S NEW
--   1. WI sub-tables (Pre-inspection, Tasks, Post-inspection, Test/KRS questions)
--      → Replaces simple wi_krs_items table with proper structured sections
--   2. OJA (On-the-Job Assessment) engine — 4 new tables
--      → This is THE killer feature: the actual mechanism that produces
--        skill matrix data (180K+ rows in legacy = real production system)
--   3. Catalog tables (JC, KR, Competency, Policy, HR Forms)
--      → Master lists referenced by assessments and JDs
--   4. Cost centers as separate entity
--   5. Shifts (ShiftName seen everywhere in OJA data)
--   6. Recruitment progression tracking
-- ============================================================================


-- =====================================================================
-- A. CATALOGS (master data referenced by assessments)
-- =====================================================================

-- Cost centers — separate from org_nodes (an org_node can map to many cost centers)
-- Real data: 132 cost centers in MEYERCAP
create table cost_centers (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- COSTCENTER
  bu_code       text,                                   -- BUCode
  hr_code       text,                                   -- HRCODE
  finance_code  text,                                   -- FINANCECODE
  org_node_id   uuid references org_nodes(id),
  purpose       text,                                   -- CostCenterPurpose
  area_manager_employee_id uuid references employees(id),
  factory_manager_employee_id uuid references employees(id),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, code)
);
create index on cost_centers(tenant_id);

-- Shift definitions (S1DAY, S2NIGHT, etc.)
create table shifts (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- "S1DAY"
  name          text not null,
  start_time    time,
  end_time      time,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (tenant_id, code)
);

-- Generic competency catalog (Managerial / Behavioural / Technical)
-- Real data: 22 competencies in MEYERCAP, categorized as Managerial-Competency
create type competency_category as enum (
  'managerial','behavioural','technical','functional','leadership','core'
);

create table competencies_catalog (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- CCODE (e.g., "MC001")
  name          text not null,                          -- COMPETENCY name
  category      competency_category not null,           -- CTYPE
  applies_to    text,                                   -- CFOR (e.g., "Senior-Manager", "All")
  description_novice text,                              -- NOVICE behavior indicator
  description_competent text,                           -- COMPETENT behavior indicator
  description_expert text,                              -- EXPERT behavior indicator
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, code)
);

-- Job Competencies linked to each position (JD)
-- Each JD has multiple JCs; each JC has a sequence
-- Real data: 196 JC entries for 189 JDs
create table position_competencies (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  position_id   uuid not null references positions(id) on delete cascade,
  jc_code       text not null,                          -- JCCode (e.g., "HR7C5")
  description   text not null,                          -- JC text
  sequence      int not null default 1,                 -- JCSequence
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (position_id, jc_code)
);
create index on position_competencies(position_id, sequence);

-- Key Responsibilities linked to each position (JD)
-- Real data: 254 KR entries for 189 JDs
create table position_key_responsibilities (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  position_id   uuid not null references positions(id) on delete cascade,
  kr_code       text not null,                          -- KRCode (e.g., "HR71")
  description   text not null,                          -- KR text (full prose)
  sequence      int not null default 1,                 -- KRSequence
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (position_id, kr_code)
);
create index on position_key_responsibilities(position_id, sequence);

-- Subordinate positions (alternative view of org hierarchy for JD assessments)
-- Real data: 33 entries
create table position_subordinates (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  manager_position_id uuid not null references positions(id) on delete cascade,
  subordinate_position_id uuid not null references positions(id) on delete cascade,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (manager_position_id, subordinate_position_id),
  check (manager_position_id != subordinate_position_id)
);

-- HR Forms catalog
-- Real data: 94 HR forms in MEYERCAP (forms for everything)
create table hr_forms (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  form_code     text not null,                          -- FormCode
  name_en       text not null,                          -- FormNameEn
  name_th       text,                                   -- FormNameTh
  section_name  text,                                   -- SectionName
  reference_code text,                                  -- ReferenceCode
  org_node_id   uuid references org_nodes(id),
  document_url  text,
  is_public     boolean default false,                  -- PublicOrNot
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (tenant_id, form_code)
);

-- Policy types catalog
create table policy_types (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- PolicyTypeCode
  name          text not null,                          -- PolicyTypeName
  is_active     boolean not null default true,
  unique (tenant_id, code)
);

-- HR Policies catalog
-- Real data: 20 policies, 7 policy types in MEYERCAP
create table policies (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- PolicyCode
  name_en       text not null,                          -- PolicyNameEN
  name_th       text,                                   -- PolicyNameTH
  type_id       uuid references policy_types(id),
  reference_code text,                                  -- PolicyRefCode
  document_url  text,
  registered_date date,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, code)
);


-- =====================================================================
-- B. WORK INSTRUCTION SUB-SECTIONS
-- =====================================================================
-- Real legacy WI has 7 sub-tables. We already have PPE/Tools/Defects.
-- Adding the missing 4:  Pre-inspection, Tasks, Post-inspection, Tests/KRS

-- Add CTQ/KRSA/VA flags to WI itself
alter table work_instructions
  add column if not exists is_ctq boolean default false,
  add column if not exists is_krsa boolean default false,
  add column if not exists is_value_added boolean default true,
  add column if not exists skill_required text;

-- WI Pre-inspection steps (what to check BEFORE starting work)
-- Real data: 178 pre-inspection rows for 192 WIs
create table wi_pre_steps (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  wi_id         uuid not null references work_instructions(id) on delete cascade,
  code          text,                                   -- WIPreCode
  sequence      int not null default 1,
  name_th       text,                                   -- PreNameTH
  name_en       text,
  detail_th     text,                                   -- PreDetailTH
  detail_en     text,
  image_url     text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on wi_pre_steps(wi_id, sequence);

-- WI Tasks (the actual work procedure)
-- Real data: 935 task rows for 192 WIs (avg ~5 tasks per WI)
-- THIS IS THE MAIN CONTENT OF A WORK INSTRUCTION
create table wi_tasks (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  wi_id         uuid not null references work_instructions(id) on delete cascade,
  code          text,                                   -- WITaskCode
  sequence      int not null,                           -- TaskSequence
  name_th       text,                                   -- TaskNameTH
  name_en       text,                                   -- TaskNameEN
  description   text,                                   -- Description
  caution       text,                                   -- Caution
  is_ctq        boolean default false,                  -- CTQ (Critical to Quality)
  image_url     text,
  video_url     text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on wi_tasks(wi_id, sequence);

-- WI Post-inspection steps (what to check AFTER finishing work)
-- Real data: 169 post-inspection rows
create table wi_post_steps (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  wi_id         uuid not null references work_instructions(id) on delete cascade,
  code          text,                                   -- WIPostCode
  sequence      int not null default 1,
  name_th       text,                                   -- PostNameTH
  name_en       text,
  detail_th     text,                                   -- PostDetailTH
  detail_en     text,
  image_url     text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on wi_post_steps(wi_id, sequence);

-- WI Test Questions (the KRS = Knowledge Review Sheet)
-- Each WI has a set of questions to test operator knowledge
-- Real data: 681 test questions across WIs
-- REPLACES wi_krs_items from v1 schema (which we drop)
drop table if exists wi_krs_items;

create table wi_test_questions (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  wi_id         uuid not null references work_instructions(id) on delete cascade,
  code          text,                                   -- WITestCode
  sequence      int not null default 1,
  question_th   text,                                   -- TestQuestionTH
  question_en   text,
  answer_th     text,                                   -- TestAnswerTH
  answer_en     text,
  question_type text default 'free_text'
                check (question_type in ('free_text','multiple_choice','yes_no','rating')),
  options       jsonb,                                  -- for multiple choice
  weight        int default 1,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on wi_test_questions(wi_id, sequence);


-- =====================================================================
-- C. OJA (On-the-Job Assessment) ENGINE ⭐ THE KILLER FEATURE
-- =====================================================================
-- REVISED MODEL (2026-05-14, after Tanawat clarification):
-- When a trainer/foreman/supervisor goes to the floor:
--   1. They open ONE OJA VISIT (date, shift, location, assessor)
--   2. Within the visit, they assess MULTIPLE workers × MULTIPLE WIs
--   3. Each (worker, WI) pair = one OJA ASSESSMENT
--   4. Each assessment has:
--        - Multiple PPE observations (one per WI's required PPE)
--        - Multiple task observations (one per WI task)
--        - Multiple defect observations (one per defect to watch)
--        - Optional test answers
--   5. Assessment result → updates skill_records with RAD level
--
-- Real data scale: 73,871 task observations roll up to ~5,000 assessments
-- which roll up to ~500-1,000 visits. Much more efficient query patterns.

create type oja_outcome as enum (
  'pass',          -- task done correctly / PPE worn / defect avoided
  'fail',          -- task done wrong / PPE missing / defect occurred
  'partial',       -- mostly correct, needs improvement
  'na',            -- not applicable for this assessment
  'aware'          -- operator is aware of (e.g., aware of defect risk)
);

create type oja_session_status as enum (
  'scheduled','in_progress','completed','cancelled','disputed'
);

create type oja_assessor_role as enum (
  'on_job_trainer','foreman','supervisor','quality_lead','manager','peer'
);

-- ONE VISIT = one assessor goes to the floor for a session of work
-- Real-world: a trainer spends 2 hours on the floor, assesses 5 workers
-- across 8 different WIs → that's 1 visit, ~10 assessments, ~100 observations.
create table oja_visits (
  id                uuid primary key default uuid_generate_v4(),
  tenant_id         uuid not null references tenants(id) on delete cascade,

  -- When & where
  visit_date        date not null,
  visit_year        int generated always as (extract(year from visit_date)::int) stored,
  visit_month       int generated always as (extract(month from visit_date)::int) stored,
  shift_id          uuid references shifts(id),
  org_node_id       uuid references org_nodes(id),

  -- Who's assessing
  assessor_employee_id uuid references employees(id),
  assessor_role     oja_assessor_role not null default 'on_job_trainer',

  -- Visit lifecycle
  status            oja_session_status not null default 'scheduled',
  started_at        timestamptz,
  completed_at      timestamptz,

  -- Summary stats (populated when visit is completed)
  workers_assessed_count int default 0,
  assessments_count int default 0,
  observations_count int default 0,

  notes             text,
  metadata          jsonb not null default '{}',
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index on oja_visits(tenant_id, visit_date desc);
create index on oja_visits(assessor_employee_id, visit_date desc);

-- ONE ASSESSMENT = one worker × one WI within a visit
-- The result here updates skill_records and skill_record_history.
create table oja_assessments (
  id                uuid primary key default uuid_generate_v4(),
  tenant_id         uuid not null references tenants(id) on delete cascade,
  visit_id          uuid not null references oja_visits(id) on delete cascade,

  -- Who is being assessed (one of these two)
  employee_id       uuid references employees(id),
  subcontract_worker_id uuid references subcontract_workers(id),

  -- What is being assessed
  wi_id             uuid not null references work_instructions(id) on delete restrict,

  -- Computed results (filled when assessment is completed)
  ppe_pass_count    int default 0,
  ppe_fail_count    int default 0,
  task_pass_count   int default 0,
  task_fail_count   int default 0,
  task_partial_count int default 0,
  defect_count      int default 0,
  test_score        numeric(5,2),                       -- % correct on test questions
  overall_result    text check (overall_result in ('pass','fail','retake','partial')),
  rad_level_awarded rad_level,                          -- '0','1','2'

  -- Sign-off
  notes             text,
  evidence_urls     text[],                             -- photos/videos for this specific assessment
  worker_signature_url text,                            -- worker's digital sign-off
  assessor_signature_url text,                          -- assessor's digital sign-off
  metadata          jsonb not null default '{}',
  completed_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  check (employee_id is not null or subcontract_worker_id is not null),

  -- One assessment per (worker, WI) within a visit
  unique (visit_id, employee_id, wi_id),
  unique (visit_id, subcontract_worker_id, wi_id)
);
create index on oja_assessments(tenant_id);
create index on oja_assessments(visit_id);
create index on oja_assessments(employee_id) where employee_id is not null;
create index on oja_assessments(subcontract_worker_id) where subcontract_worker_id is not null;
create index on oja_assessments(wi_id);

-- Observations are now linked to ASSESSMENT (not session), giving us full traceability
-- back through assessment → visit → assessor.

-- Each task observed during the assessment
-- Real data: 73,871 rows
create table oja_task_observations (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  oja_assessment_id uuid not null references oja_assessments(id) on delete cascade,
  wi_task_id    uuid not null references wi_tasks(id) on delete restrict,
  outcome       oja_outcome not null,
  notes         text,
  evidence_url  text,
  created_at    timestamptz not null default now(),
  unique (oja_assessment_id, wi_task_id)
);
create index on oja_task_observations(oja_assessment_id);

-- Each PPE checked during the assessment
-- Real data: 66,839 rows
create table oja_ppe_observations (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  oja_assessment_id uuid not null references oja_assessments(id) on delete cascade,
  wi_ppe_requirement_id uuid not null references wi_ppe_requirements(id) on delete restrict,
  outcome       oja_outcome not null,                   -- 'pass' = wearing it; 'fail' = not wearing
  notes         text,
  evidence_url  text,
  created_at    timestamptz not null default now(),
  unique (oja_assessment_id, wi_ppe_requirement_id)
);
create index on oja_ppe_observations(oja_assessment_id);

-- Each defect awareness / occurrence noted during the assessment
-- Real data: 42,215 rows
create table oja_defect_observations (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  oja_assessment_id uuid not null references oja_assessments(id) on delete cascade,
  wi_defect_check_id uuid not null references wi_defect_checks(id) on delete restrict,
  outcome       oja_outcome not null,                   -- 'aware' = knows about, 'fail' = defect happened
  defect_count  int default 0,                          -- if 'fail', how many defects produced
  notes         text,
  evidence_url  text,
  created_at    timestamptz not null default now(),
  unique (oja_assessment_id, wi_defect_check_id)
);
create index on oja_defect_observations(oja_assessment_id);

-- Each test question answered during the assessment (if test was administered)
create table oja_test_answers (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  oja_assessment_id uuid not null references oja_assessments(id) on delete cascade,
  wi_test_question_id uuid not null references wi_test_questions(id) on delete restrict,
  given_answer  text,
  is_correct    boolean,
  score         int,
  notes         text,
  created_at    timestamptz not null default now(),
  unique (oja_assessment_id, wi_test_question_id)
);


-- =====================================================================
-- D. RECRUITMENT PROGRESSION TRACKING
-- =====================================================================
-- Real data: RecruitTrackingTable (71 rows), MatchToRoleTable (40 rows)

create table candidate_role_matches (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  candidate_id  uuid not null references candidates(id) on delete cascade,
  requisition_id uuid not null references staff_requisitions(id) on delete cascade,
  match_score   numeric(5,2),                          -- 0-100 fit score
  match_notes   text,
  recommended_by_employee_id uuid references employees(id),
  recommend_date date,
  created_at    timestamptz not null default now(),
  unique (candidate_id, requisition_id)
);

-- Recruitment progression timeline (every state change tracked)
create table recruitment_progression_log (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  candidate_application_id uuid not null references candidate_applications(id) on delete cascade,
  previous_stage text,
  new_stage     text not null,
  change_reason text,
  changed_by_employee_id uuid references employees(id),
  changed_at    timestamptz not null default now()
);
create index on recruitment_progression_log(candidate_application_id, changed_at);


-- =====================================================================
-- E. TRAINING ATTENDANCE & TR SHARE
-- =====================================================================
-- Real data: attendance (5,292), TR (558), TRShare (61)

-- Pictures / evidence linked to a training record
-- This was TRShare in legacy
create table training_record_attachments (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  training_record_id uuid not null references training_records(id) on delete cascade,
  caption_en    text,                                   -- PictureCaptionEN
  caption_th    text,                                   -- PictureCaptionTH
  attachment_url text not null,                         -- Supabase Storage URL
  attachment_type text default 'photo'
                  check (attachment_type in ('photo','video','document','signature')),
  sequence      int default 1,                          -- PicSequence
  uploaded_by_employee_id uuid references employees(id),
  created_at    timestamptz not null default now()
);


-- =====================================================================
-- F. RLS for all new tables
-- =====================================================================

do $$
declare t text;
declare new_tables text[] := array[
  'cost_centers','shifts','competencies_catalog','position_competencies',
  'position_key_responsibilities','position_subordinates','hr_forms',
  'policy_types','policies','wi_pre_steps','wi_tasks','wi_post_steps',
  'wi_test_questions','oja_visits','oja_assessments','oja_task_observations',
  'oja_ppe_observations','oja_defect_observations','oja_test_answers',
  'candidate_role_matches','recruitment_progression_log','training_record_attachments'
];
begin
  foreach t in array new_tables loop
    execute format('alter table %I enable row level security;', t);
    execute format(
      'drop policy if exists tenant_isolation on %I;
       create policy tenant_isolation on %I
       using (tenant_id in (select current_tenant_ids()));',
      t, t, t
    );
  end loop;
end$$;


-- =====================================================================
-- G. New permissions
-- =====================================================================

insert into permissions (code, module, description) values
  ('oja.visit_create',        'training',    'Start an OJA floor visit'),
  ('oja.visit_complete',      'training',    'Complete an OJA visit'),
  ('oja.assessment_create',   'training',    'Add a worker assessment to a visit'),
  ('oja.assessment_complete', 'training',    'Complete & sign-off a single assessment'),
  ('oja.assessment_dispute',  'training',    'Dispute an OJA assessment result'),
  ('oja.view_all',            'training',    'View all OJA visits/assessments across tenant'),
  ('competency.read',         'people',      'View competency catalogs'),
  ('competency.manage',       'people',      'Manage competencies, JCs, KRs'),
  ('policy.read',             'people',      'View HR policies'),
  ('policy.manage',           'people',      'Manage HR policies'),
  ('hr_forms.read',           'people',      'View HR forms catalog'),
  ('hr_forms.manage',         'people',      'Manage HR forms catalog'),
  ('cost_center.read',        'admin',       'View cost centers'),
  ('cost_center.manage',      'admin',       'Manage cost centers')
on conflict (code) do update set
  module = excluded.module,
  description = excluded.description;


-- =====================================================================
-- H. Views for common queries (performance + simpler app code)
-- =====================================================================

-- Skill matrix view: one row per (worker, WI) with all key info
create or replace view v_skill_matrix as
select
  sr.tenant_id,
  sr.id as skill_record_id,
  coalesce(e.id, sw.id) as worker_id,
  case when e.id is not null then 'employee' else 'subcontract' end as worker_type,
  coalesce(e.employee_code, sw.worker_code) as worker_code,
  coalesce(e.first_name_en, sw.first_name_en) as first_name_en,
  coalesce(e.last_name_en, sw.last_name_en) as last_name_en,
  coalesce(e.org_node_id, sw.org_node_id) as org_node_id,
  coalesce(e.position_id, sw.position_id) as position_id,
  wi.id as wi_id,
  wi.code as wi_code,
  wi.name_en as wi_name_en,
  wi.org_node_id as wi_org_node_id,
  sr.rad_level,
  sr.status as skill_status,
  sr.is_rad_role_model,
  sr.last_assessed_at,
  sr.last_krs_score,
  sr.certified_at,
  sr.expires_at,
  case
    when sr.expires_at is null then false
    when sr.expires_at < now() then true
    else false
  end as is_expired,
  case
    when sr.expires_at is null then null
    when sr.expires_at < now() + interval '30 days' then true
    else false
  end as is_expiring_soon
from skill_records sr
left join employees e on sr.employee_id = e.id
left join subcontract_workers sw on sr.subcontract_worker_id = sw.id
join work_instructions wi on sr.wi_id = wi.id;

-- OJA assessment summary view (latest 90 days) with visit context
create or replace view v_recent_oja_assessments as
select
  a.tenant_id,
  a.id as assessment_id,
  v.id as visit_id,
  v.visit_date,
  v.shift_id,
  v.assessor_role,
  a.wi_id,
  wi.code as wi_code,
  wi.name_en as wi_name,
  coalesce(e.employee_code, sw.worker_code) as worker_code,
  case when e.id is not null then 'employee' else 'subcontract' end as worker_type,
  coalesce(e.first_name_en, sw.first_name_en) as worker_first_name,
  coalesce(e.last_name_en, sw.last_name_en) as worker_last_name,
  ae.employee_code as assessor_code,
  ae.first_name_en as assessor_first_name,
  a.overall_result,
  a.rad_level_awarded,
  a.task_pass_count,
  a.task_fail_count,
  a.task_partial_count,
  a.ppe_pass_count,
  a.ppe_fail_count,
  a.defect_count,
  a.test_score,
  v.status as visit_status,
  a.completed_at
from oja_assessments a
join oja_visits v on a.visit_id = v.id
left join employees e on a.employee_id = e.id
left join subcontract_workers sw on a.subcontract_worker_id = sw.id
join work_instructions wi on a.wi_id = wi.id
left join employees ae on v.assessor_employee_id = ae.id
where v.visit_date > current_date - interval '90 days'
order by v.visit_date desc, a.created_at desc;

-- OJA visit summary view (productivity reporting)
create or replace view v_oja_visit_summary as
select
  v.tenant_id,
  v.id as visit_id,
  v.visit_date,
  v.visit_year,
  v.visit_month,
  v.assessor_role,
  ae.employee_code as assessor_code,
  ae.first_name_en as assessor_first_name,
  ae.last_name_en as assessor_last_name,
  v.org_node_id,
  v.status,
  v.workers_assessed_count,
  v.assessments_count,
  v.observations_count,
  v.started_at,
  v.completed_at,
  extract(epoch from (v.completed_at - v.started_at)) / 60 as duration_minutes
from oja_visits v
left join employees ae on v.assessor_employee_id = ae.id;


-- =====================================================================
-- END OF SCHEMA V2 ADDITIONS
-- =====================================================================
-- After applying:
--   1. Drop legacy table noise (Paste_Errors, FOP, MonthTable) — no need to import
--   2. SkillRecordExpired is just a status; merge into skill_records
--   3. GroupTable, FamilyTable → roll into org_nodes hierarchy at migration time
--
-- The schema is now ~55 tables (38 from v1 + 17 from v2 additions).
-- Covers ~95% of legacy MEYERCAP functionality.
-- =====================================================================
