-- ============================================================================
-- PTMS v1 — Multi-tenant Postgres schema for Supabase
-- ============================================================================
-- Date drafted:  2026-05-13
-- Author:        Claude (overnight)
-- Status:        DRAFT — review with Tanawat before applying
-- Source:        Legacy MEYERCAP ASP analysis (1076 files, 309 fields, ~35 tables)
--                + answered design questions on Bluemat/RAD/JD assessment
-- ============================================================================
--
-- DESIGN PRINCIPLES
--
-- 1. Multi-tenant from day 1.
--    Every business table has tenant_id with RLS policies enforcing isolation.
--
-- 2. UUIDs everywhere.
--    Supabase convention; safer than sequential IDs for SaaS.
--
-- 3. Soft delete via deleted_at.
--    Production HR data must never be hard-deleted (compliance + audit).
--
-- 4. Bilingual content (name_en, name_th).
--    Legacy system has TH+EN columns; keep that pattern.
--    For free-text user content, store in JSONB with locale keys.
--
-- 5. Audit columns on every table:
--      created_at, updated_at (auto via triggers)
--      created_by, updated_by (auth.uid())
--
-- 6. Postgres-native enums for closed-vocabulary status fields.
--    Open-vocabulary (free-text + reference table) for things that vary by tenant.
--
-- 7. RAD skill scale is a strict 0/1/2 enum — locked, drives pay decisions.
--
-- 8. Bluemat (subcontract) workers are a SEPARATE entity from employees.
--    They're not employed by the tenant; they're employed by an agency.
--    But they appear in skill matrix, attendance, PPE, defects, training records.
--
-- ============================================================================

-- =====================================================================
-- 0. EXTENSIONS
-- =====================================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";  -- fuzzy text search


-- =====================================================================
-- 1. TENANCY & ACCESS CONTROL
-- =====================================================================

-- Each customer (factory company) is a tenant.
create table tenants (
  id            uuid primary key default uuid_generate_v4(),
  slug          text unique not null,                   -- url-safe: meyer-cap, sumitomo-tha
  display_name  text not null,                          -- "Meyer Industries Thailand"
  legal_name    text,
  country       text default 'TH',
  default_locale text default 'en' check (default_locale in ('en','th')),
  logo_url      text,
  status        text not null default 'active'
                check (status in ('active','suspended','cancelled')),
  plan          text not null default 'trial'
                check (plan in ('trial','starter','professional','enterprise')),
  trial_ends_at timestamptz,
  settings      jsonb not null default '{}',            -- feature flags, branding
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);
create index on tenants(slug);
create index on tenants(status) where deleted_at is null;

-- Profile extends Supabase auth.users with our app-specific fields.
-- One profile per auth user; user can belong to multiple tenants via tenant_members.
create table profiles (
  id            uuid primary key references auth.users on delete cascade,
  full_name     text,
  display_name  text,
  email         text not null,
  phone         text,
  avatar_url    text,
  preferred_locale text default 'en' check (preferred_locale in ('en','th')),
  last_seen_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Roles are tenant-scoped. Each tenant can have custom roles, but starts with defaults.
create table roles (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- "admin", "trainer", "quality", "employee", custom...
  display_name  text not null,
  description   text,
  is_system     boolean not null default false,         -- system roles can't be deleted
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, code)
);

-- Permission catalog (global; not tenant-scoped).
-- Permissions are flat strings like "wi.create", "skill_matrix.certify", etc.
create table permissions (
  code          text primary key,
  module        text not null,                          -- "training", "hr", "recruitment"...
  description   text not null
);

create table role_permissions (
  role_id       uuid not null references roles(id) on delete cascade,
  permission_code text not null references permissions(code) on delete cascade,
  primary key (role_id, permission_code)
);

-- Users belong to one or more tenants, each with one or more roles.
create table tenant_members (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  profile_id    uuid not null references profiles(id) on delete cascade,
  employee_id   uuid,                                   -- forward ref: linked employee record (FK added later)
  status        text not null default 'active' check (status in ('active','invited','suspended')),
  invited_by    uuid references profiles(id),
  invited_at    timestamptz,
  joined_at     timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, profile_id)
);
create index on tenant_members(tenant_id);
create index on tenant_members(profile_id);

create table tenant_member_roles (
  tenant_member_id uuid not null references tenant_members(id) on delete cascade,
  role_id          uuid not null references roles(id) on delete cascade,
  primary key (tenant_member_id, role_id)
);


-- =====================================================================
-- 2. ORGANIZATION STRUCTURE (per tenant)
-- =====================================================================

-- Legacy uses: Group → Family → OrgCode → Area
-- Plus parallel concepts: CostCenter, FinanceCode, PayrollOrgCode
-- New design: a flexible tree with typed nodes per tenant.

create type org_node_type as enum (
  'group',          -- Top level (e.g., "Manufacturing")
  'family',         -- Functional grouping (e.g., "Production")
  'department',     -- Department (e.g., "Press")
  'area',           -- Physical area (e.g., "Cell 3")
  'cost_center',    -- Cost center for finance
  'team'            -- Smallest unit
);

create table org_nodes (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  parent_id     uuid references org_nodes(id) on delete restrict,
  node_type     org_node_type not null,
  code          text not null,                          -- legacy code, e.g., "ORG-001"
  name_en       text not null,
  name_th       text,
  cost_center_code text,
  finance_code  text,
  payroll_code  text,
  is_active     boolean not null default true,
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  unique (tenant_id, code)
);
create index on org_nodes(tenant_id, parent_id);
create index on org_nodes(tenant_id, node_type);

-- Position levels (e.g., Operator, Senior Operator, Lead, Supervisor, Manager)
create table position_levels (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,
  name_en       text not null,
  name_th       text,
  rank          int not null,                           -- 1 = lowest, higher = more senior
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, code)
);

-- Positions / job descriptions (the master JD list)
create table positions (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- JDCode
  common_name   text not null,                          -- PositionCommonName
  full_name_en  text not null,                          -- JDName
  full_name_th  text,
  position_level_id uuid references position_levels(id),
  org_node_id   uuid references org_nodes(id),         -- home dept/team
  jd_status     text default 'active' check (jd_status in ('draft','active','archived')),
  jd_document_url text,                                 -- link to JD doc
  is_subcontract_role boolean not null default false,  -- can Bluemat workers hold this position?
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  unique (tenant_id, code)
);
create index on positions(tenant_id, org_node_id);


-- =====================================================================
-- 3. EMPLOYEES & SUBCONTRACT (BLUEMAT) WORKERS
-- =====================================================================

create type gender_type as enum ('male','female','other','prefer_not_to_say');
create type employment_status as enum (
  'active',
  'on_probation',
  'on_leave',
  'resigned',
  'terminated',
  'retired'
);

-- Direct employees of the tenant.
create table employees (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  employee_code text not null,                          -- EmpCode

  -- Names (bilingual)
  prefix_en     text,
  first_name_en text not null,
  last_name_en  text not null,
  prefix_th     text,
  first_name_th text,
  last_name_th  text,

  -- Personal
  citizen_id    text,                                   -- masked / encrypted in app
  date_of_birth date,
  gender        gender_type,
  nationality   text default 'TH',

  -- Contact
  email         text,
  phone         text,
  internal_phone text,                                  -- InternalTelephone (extension)
  living_area   text,                                   -- LivingArea

  -- Photo
  photo_url     text,                                   -- Supabase Storage url

  -- Employment
  employment_status employment_status not null default 'active',
  employment_date date,                                 -- EmploymentDate
  termination_date date,
  position_id   uuid references positions(id),
  org_node_id   uuid references org_nodes(id),
  cost_center_code text,                                -- can differ from org_node cost center
  emp_group_code text,                                  -- EmpGroupCode (band/grade)
  emp_level     text,                                   -- EmpLevel

  -- Reporting
  reports_to_employee_id uuid references employees(id),
  dotted_line_to_employee_id uuid references employees(id),

  -- Education (denormalized snapshot; full history could be separate table later)
  education         text,
  education_major   text,
  university        text,

  -- Misc
  metadata      jsonb not null default '{}',
  notes         text,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  unique (tenant_id, employee_code)
);
create index on employees(tenant_id, employment_status) where deleted_at is null;
create index on employees(tenant_id, org_node_id);
create index on employees(tenant_id, position_id);
create index on employees(tenant_id, reports_to_employee_id);
create index employees_name_trgm on employees using gin
  ((first_name_en || ' ' || last_name_en) gin_trgm_ops);

-- Now we can FK tenant_members.employee_id back to employees.
alter table tenant_members
  add constraint tenant_members_employee_id_fkey
  foreign key (employee_id) references employees(id) on delete set null;

-- Subcontract agencies (Bluemat vendors)
create table agencies (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,
  name          text not null,
  contact_person text,
  email         text,
  phone         text,
  address       text,
  contract_terms text,
  status        text not null default 'active' check (status in ('active','suspended','terminated')),
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  unique (tenant_id, code)
);

-- Subcontract (Bluemat) workers — supplied by agencies, not employed by tenant.
create table subcontract_workers (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  agency_id     uuid not null references agencies(id) on delete restrict,
  worker_code   text not null,                          -- agency-assigned or tenant-assigned

  prefix_en     text,
  first_name_en text not null,
  last_name_en  text not null,
  prefix_th     text,
  first_name_th text,
  last_name_th  text,

  citizen_id    text,
  date_of_birth date,
  gender        gender_type,

  phone         text,
  email         text,
  photo_url     text,

  -- Placement
  position_id   uuid references positions(id),
  org_node_id   uuid references org_nodes(id),
  start_date    date not null,
  end_date      date,                                   -- when returned to agency
  contract_period text,
  hourly_rate   numeric(10,2),                          -- ContractPeriod, Fee
  status        text not null default 'active'
                check (status in ('active','returned','rejected_by_agency','ended')),

  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  unique (tenant_id, worker_code)
);
create index on subcontract_workers(tenant_id, agency_id);
create index on subcontract_workers(tenant_id, status) where deleted_at is null;

-- Bluemat budgets — pre-allocated headcount/cost per cost center per period.
create table subcontract_budgets (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  org_node_id   uuid not null references org_nodes(id),
  fiscal_year   int not null,
  fiscal_month  int,                                    -- null = annual
  budget_type   text not null,                          -- BudgetType (e.g., headcount, cost)
  approved_headcount int,
  approved_cost numeric(14,2),
  notes         text,
  created_by    uuid references profiles(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on subcontract_budgets(tenant_id, fiscal_year, org_node_id);

-- Bluemat requests — request more workers from agencies
create type bm_request_status as enum (
  'draft','submitted','approved_supervisor','approved_finance',
  'approved_hr','rejected','filled','cancelled'
);

create table subcontract_requests (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  request_no    text not null,                          -- BMRequestID
  org_node_id   uuid not null references org_nodes(id),
  position_id   uuid references positions(id),
  quantity      int not null,
  quantity_balance int,                                 -- QuantityBalance (still to fulfill)
  expected_start_date date,
  agency_id     uuid references agencies(id),
  request_reason text,
  requested_by_employee_id uuid references employees(id),
  status        bm_request_status not null default 'draft',
  approved_by_employee_id uuid references employees(id),
  approval_date date,
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, request_no)
);
create index on subcontract_requests(tenant_id, status);

-- Attendance — for BOTH employees and subcontract workers.
-- Polymorphic via 2 nullable FKs (only one set per row).
create table attendance_records (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  employee_id   uuid references employees(id),
  subcontract_worker_id uuid references subcontract_workers(id),
  attendance_date date not null,
  shift_code    text,
  clock_in      timestamptz,
  clock_out     timestamptz,
  hours_worked  numeric(5,2),
  status        text not null default 'present'
                check (status in ('present','absent','leave','holiday','off_day')),
  notes         text,
  source        text not null default 'manual'
                check (source in ('manual','clock','import','api')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (employee_id is not null or subcontract_worker_id is not null)
);
create index on attendance_records(tenant_id, attendance_date);
create index on attendance_records(employee_id, attendance_date) where employee_id is not null;
create index on attendance_records(subcontract_worker_id, attendance_date) where subcontract_worker_id is not null;


-- =====================================================================
-- 4. WORK INSTRUCTIONS + KRS + PPE + TOOLS + DEFECTS
-- =====================================================================
-- A WI is the master training document for a specific workstation/task.
-- Each WI has: required PPE, required tools, defect checks, and a KRS
-- (Knowledge Review Sheet) that's the test/checklist for certification.

create type wi_status as enum ('draft','published','under_review','archived');

create table work_instructions (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- WICode
  name_en       text not null,                          -- WINameEN
  name_th       text,                                   -- WINameTH

  -- Where it applies
  org_node_id   uuid references org_nodes(id),
  position_id   uuid references positions(id),

  -- Lifecycle
  version       int not null default 1,
  status        wi_status not null default 'draft',
  published_at  timestamptz,
  published_by  uuid references profiles(id),

  -- Recertification rules
  recert_interval_months int,                           -- null = no expiry
  next_review_due_date date,

  -- Content
  cycle_time_seconds int,                               -- CycleTime
  description   text,
  purpose       text,
  content       jsonb not null default '{}',            -- rich text / structured sections

  created_by    uuid references profiles(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  unique (tenant_id, code, version)
);
create index on work_instructions(tenant_id, status) where deleted_at is null;
create index on work_instructions(tenant_id, org_node_id);

-- PPE catalog (tenant-level)
create table ppe_catalog (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- PPECode
  name_en       text not null,                          -- PPENameEN
  name_th       text,                                   -- PPENameTH
  purpose_en    text,                                   -- PPEPurposeEN
  purpose_th    text,                                   -- PPEPurposeTH
  category      text,
  image_url     text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, code)
);

create table wi_ppe_requirements (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  wi_id         uuid not null references work_instructions(id) on delete cascade,
  ppe_id        uuid not null references ppe_catalog(id) on delete restrict,
  is_required   boolean not null default true,
  notes         text,
  created_at    timestamptz not null default now(),
  unique (wi_id, ppe_id)
);

-- Tools catalog
create table tools_catalog (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- TOOLCode
  name_en       text not null,                          -- TOOLNameEN
  name_th       text,                                   -- TOOLNameTH
  category      text,                                   -- StandardToolTable category
  image_url     text,
  is_standard   boolean not null default false,         -- standard kit vs specific tool
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, code)
);

create table wi_tool_requirements (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  wi_id         uuid not null references work_instructions(id) on delete cascade,
  tool_id       uuid not null references tools_catalog(id) on delete restrict,
  quantity      int default 1,
  notes         text,
  unique (wi_id, tool_id)
);

-- Defects checks per WI
create table wi_defect_checks (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  wi_id         uuid not null references work_instructions(id) on delete cascade,
  defect_code   text not null,                          -- DefectCode
  name_en       text not null,                          -- DefectNameEN
  name_th       text,                                   -- DefectNameTH
  detail_en     text,                                   -- DefectDetailEN
  detail_th     text,                                   -- DefectDetailTH
  severity      text check (severity in ('critical','major','minor','cosmetic')),
  image_url     text,
  sequence      int default 1,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (wi_id, defect_code)
);

-- KRS (Knowledge Review Sheet) — the assessment checklist linked to a WI
create table wi_krs_items (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  wi_id         uuid not null references work_instructions(id) on delete cascade,
  krs_code      text,                                   -- KRCode
  sequence      int not null,                           -- KRSequence
  question_en   text not null,
  question_th   text,
  expected_answer text,
  weight        int default 1,
  pass_threshold int,                                   -- e.g., 80% of weight required
  created_at    timestamptz not null default now()
);
create index on wi_krs_items(wi_id, sequence);


-- =====================================================================
-- 5. SKILL MATRIX (RAD 3-level scale)
-- =====================================================================
-- Each employee or subcontract worker × each WI = one row.
-- RAD skill level: 0 (training), 1 (practicing/supervised), 2 (certified + can train others).

create type rad_level as enum ('0','1','2');
create type skill_status as enum (
  'not_assigned',         -- not yet trained on this WI
  'in_training',          -- Level 0
  'practicing',           -- Level 1
  'certified',            -- Level 2
  'expired',              -- recert overdue
  'revoked'               -- competency removed
);

create table skill_records (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,

  -- Polymorphic worker reference (one of two must be set)
  employee_id   uuid references employees(id) on delete cascade,
  subcontract_worker_id uuid references subcontract_workers(id) on delete cascade,

  wi_id         uuid not null references work_instructions(id) on delete restrict,

  -- Current state
  rad_level     rad_level,
  status        skill_status not null default 'not_assigned',
  is_rad_role_model boolean not null default false,     -- designated role model for this WI

  -- Last assessment
  last_assessed_at timestamptz,
  last_assessed_by_employee_id uuid references employees(id),
  last_krs_score numeric(5,2),                          -- % score on KRS

  -- Recertification tracking
  certified_at  timestamptz,
  expires_at    timestamptz,
  recert_reminder_sent_at timestamptz,

  -- Audit
  notes         text,
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  check (employee_id is not null or subcontract_worker_id is not null),
  unique (employee_id, wi_id),
  unique (subcontract_worker_id, wi_id)
);
create index on skill_records(tenant_id, status);
create index on skill_records(tenant_id, expires_at) where status = 'certified';
create index on skill_records(wi_id);

-- History of skill level changes (every certification event)
create table skill_record_history (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  skill_record_id uuid not null references skill_records(id) on delete cascade,
  previous_level rad_level,
  new_level     rad_level,
  reason        text,
  evidence_url  text,                                   -- signed photo, KRS doc
  assessed_by_employee_id uuid references employees(id),
  assessed_at   timestamptz not null default now(),
  metadata      jsonb not null default '{}'
);
create index on skill_record_history(skill_record_id, assessed_at desc);


-- =====================================================================
-- 6. TRAINING RECORDS (delivery events)
-- =====================================================================
-- TR = Training Record (a delivery event with attendees)
-- Can be:
--   - WI-based training (linked to WI + skill assessment)
--   - Topic-based training (general topics like Safety Awareness, 5S, etc.)

create type training_type as enum ('wi_certification','topic','external','onboarding','refresher');
create type training_record_status as enum ('scheduled','in_progress','completed','cancelled');

-- Training topics (generic catalog of training subjects beyond WIs)
create table training_topics (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- TrainingCode
  name_en       text not null,                          -- Topic
  name_th       text,
  description   text,
  duration_hours numeric(5,2),
  category      text,                                   -- Safety, Quality, Skills, Soft Skills
  is_mandatory  boolean not null default false,
  validity_months int,                                  -- how long the cert stays valid
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, code)
);

create table training_records (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  tr_no         text not null,                          -- TRNO
  tr_code       text,                                   -- TRCode

  training_type training_type not null,
  wi_id         uuid references work_instructions(id),
  topic_id      uuid references training_topics(id),

  title         text not null,
  training_date date not null,
  start_time    time,
  end_time      time,
  duration_hours numeric(5,2),
  location      text,

  trainer_employee_id uuid references employees(id),    -- OJT or trainer
  external_provider text,                               -- if outside trainer
  cost          numeric(12,2),
  cost_type     text check (cost_type in ('inhouse','public','external')),

  status        training_record_status not null default 'scheduled',
  notes         text,

  created_by    uuid references profiles(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, tr_no)
);
create index on training_records(tenant_id, training_date);
create index on training_records(tenant_id, status);

-- Attendees on a training record (TRShare in legacy = multi-trainee sharing)
create table training_record_attendees (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  training_record_id uuid not null references training_records(id) on delete cascade,
  employee_id   uuid references employees(id),
  subcontract_worker_id uuid references subcontract_workers(id),
  attendance_status text not null default 'attended'
                    check (attendance_status in ('attended','absent','partial','excused')),

  -- Assessment outcome (if this training was a cert event)
  result        text check (result in ('pass','fail','retake','pending')),
  krs_score     numeric(5,2),
  rad_level_awarded rad_level,
  evidence_url  text,                                   -- signed acknowledgment, photo
  comments      text,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (employee_id is not null or subcontract_worker_id is not null)
);
create index on training_record_attendees(training_record_id);
create index on training_record_attendees(employee_id);
create index on training_record_attendees(subcontract_worker_id);


-- =====================================================================
-- 7. DEFECTS LOG & PPE ISSUANCE
-- =====================================================================
-- Production-floor logs (defects found, PPE issued) — used by Quality & Safety leads.

create table defect_log (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  defect_date   date not null,
  shift_code    text,
  org_node_id   uuid references org_nodes(id),
  wi_id         uuid references work_instructions(id),
  defect_code   text,                                   -- matches wi_defect_checks.defect_code
  detected_by_employee_id uuid references employees(id),
  operator_employee_id uuid references employees(id),
  operator_subcontract_worker_id uuid references subcontract_workers(id),
  description   text,
  quantity      int default 1,
  severity      text check (severity in ('critical','major','minor','cosmetic')),
  containment_action text,
  root_cause    text,
  corrective_action text,
  status        text not null default 'open'
                check (status in ('open','investigating','contained','closed')),
  closed_at     timestamptz,
  photo_urls    text[],                                 -- array of Supabase Storage urls
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on defect_log(tenant_id, defect_date desc);
create index on defect_log(tenant_id, status) where status != 'closed';

create table ppe_issuance_log (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  issue_date    date not null,
  ppe_id        uuid not null references ppe_catalog(id),
  employee_id   uuid references employees(id),
  subcontract_worker_id uuid references subcontract_workers(id),
  quantity      int not null default 1,
  reason        text,                                   -- replacement, new hire, expired, lost
  issued_by_employee_id uuid references employees(id),
  next_replacement_due date,
  created_at    timestamptz not null default now(),
  check (employee_id is not null or subcontract_worker_id is not null)
);
create index on ppe_issuance_log(tenant_id, issue_date desc);


-- =====================================================================
-- 8. JD ANNUAL ASSESSMENT (6 dimensions × Close-the-Gap workflow)
-- =====================================================================
-- The 6 dimensions of the annual JD review:
--   Purpose  — Purpose of the Role alignment
--   JC       — Job Competency
--   KR       — Key Responsibility
--   CS       — Computer Skill
--   LC       — License/Certificate
--   LP       — Language Proficiency

create table assessment_cycles (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  year          int not null,                           -- AssessmentYear
  cycle_name    text not null,                          -- e.g., "2026 Annual Review"
  starts_at     date not null,
  ends_at       date not null,
  status        text not null default 'planned'
                check (status in ('planned','open','in_review','closed')),
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, year)
);

-- One row per employee per cycle (the assessment header)
create table jd_assessments (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  assessment_cycle_id uuid not null references assessment_cycles(id) on delete cascade,
  employee_id   uuid not null references employees(id),
  position_id   uuid references positions(id),         -- snapshot at assessment time
  assessor_employee_id uuid references employees(id),
  reviewed_by_employee_id uuid references employees(id),  -- skip-level approver
  status        text not null default 'draft'
                check (status in (
                  'draft','self_review','manager_review',
                  'reviewer_review','finalized','closed'
                )),
  finalized_at  timestamptz,
  overall_comment text,
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (assessment_cycle_id, employee_id)
);
create index on jd_assessments(tenant_id, status);

-- Dimension result codes
create type jd_dimension as enum ('purpose','jc','kr','cs','lc','lp');

-- JC scale: NOVICE → ADVANCED-BEGINNER → COMPETENT → PROFICIENT → EXPERT (or N/A)
-- KR scale: NEED-IMPROVEMENT → MEET-EXPECTATIONS → EXCEED-EXPECTATIONS → LEADING-PERFORMANCE (or NEW-IN-ROLE)
-- We use a generic text "result" + dimension to allow per-dimension scales.

create table jd_assessment_dimensions (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  jd_assessment_id uuid not null references jd_assessments(id) on delete cascade,
  dimension     jd_dimension not null,

  -- The assessment result
  result        text,                                   -- value depends on dimension
  comment       text,

  -- Priority for development
  priority_level text check (priority_level in ('low','medium','high','critical','none')),
  priority_comment text,

  -- Development plan (a.k.a. "Close the Gap")
  dev_action    text,
  dev_due_date  date,
  dev_measurement text,
  dev_status    text check (dev_status in ('not_started','in_progress','blocked','completed','closed')),
  dev_follow_up_notes text,
  dev_closed_at timestamptz,
  dev_closed_by_employee_id uuid references employees(id),

  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (jd_assessment_id, dimension)
);

-- Career progression history (promotions, lateral moves, level changes)
create table progression_records (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  employee_id   uuid not null references employees(id) on delete cascade,
  progression_date date not null,
  from_position_id uuid references positions(id),
  to_position_id uuid references positions(id),
  from_org_node_id uuid references org_nodes(id),
  to_org_node_id uuid references org_nodes(id),
  reason        text,
  notes         text,
  effective_date date,
  created_at    timestamptz not null default now()
);
create index on progression_records(tenant_id, employee_id, progression_date desc);


-- =====================================================================
-- 9. HR WORKFLOWS — Resignation & Transfer
-- =====================================================================

create type approval_status as enum (
  'pending','approved','rejected','withdrawn','cancelled'
);

create table resignation_requests (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  employee_id   uuid not null references employees(id),
  submitted_at  date not null,
  reason        text not null,
  last_working_date date,
  request_replacement boolean default true,
  manager_decision approval_status default 'pending',
  manager_decision_at timestamptz,
  hr_decision   approval_status default 'pending',
  hr_decision_at timestamptz,
  final_status  approval_status default 'pending',
  notes         text,
  attachments   jsonb default '[]',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on resignation_requests(tenant_id, final_status);

create table transfer_requests (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  employee_id   uuid not null references employees(id),
  submitted_at  date not null,
  from_org_node_id uuid references org_nodes(id),
  from_position_id uuid references positions(id),
  to_org_node_id uuid references org_nodes(id),
  to_position_id uuid references positions(id),
  effective_date date,
  reason        text,
  from_manager_decision approval_status default 'pending',
  to_manager_decision approval_status default 'pending',
  hr_decision   approval_status default 'pending',
  final_status  approval_status default 'pending',
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);


-- =====================================================================
-- 10. RECRUITMENT PIPELINE (full structure; v2 surface UI)
-- =====================================================================
-- Tables ready for v2 launch; we won't build full UI in v1 but schema is in place.

create table hiring_managers (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  employee_id   uuid not null references employees(id) on delete cascade,
  is_active     boolean not null default true,
  specialties   text[],
  created_at    timestamptz not null default now(),
  unique (tenant_id, employee_id)
);

create table candidate_sources (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- SourcingCode
  name          text not null,                          -- SourcingFrom (LinkedIn, JobsDB, walk-in, referral, etc.)
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (tenant_id, code)
);

create type req_status as enum (
  'draft','open','sourcing','interviewing','offered','filled','on_hold','cancelled','closed'
);

create table staff_requisitions (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  req_no        text not null,
  position_id   uuid not null references positions(id),
  org_node_id   uuid not null references org_nodes(id),
  hiring_manager_id uuid references hiring_managers(id),
  recruiter_employee_id uuid references employees(id),
  requested_by_employee_id uuid references employees(id),
  request_date  date not null,
  approval_date date,
  expected_start_date date,
  vacancies_total int not null default 1,
  vacancies_filled int not null default 0,
  vacancies_balance int generated always as (vacancies_total - vacancies_filled) stored,
  is_replacement boolean default false,
  replacement_for_employee_id uuid references employees(id),
  status        req_status not null default 'draft',
  closing_date  date,
  closing_reason text,
  job_summary   text,
  required_skills text,
  contract_period text,
  fee           numeric(12,2),                          -- agency fee
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, req_no)
);

create type candidate_type as enum ('internal','external','referral','agency','rehire');

create table candidates (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,

  prefix_en     text,
  first_name_en text not null,
  last_name_en  text not null,
  prefix_th     text,
  first_name_th text,
  last_name_th  text,

  email         text,
  phone         text,
  citizen_id    text,                                   -- encrypted
  date_of_birth date,
  gender        gender_type,

  education     text,
  education_major text,
  university    text,
  experience_summary text,
  service_at_current_company text,                      -- ServiceAtCurrentCompany
  current_company text,
  candidate_type candidate_type not null default 'external',

  resume_url    text,
  photo_url     text,
  notes         text,

  status        text not null default 'active'
                check (status in ('active','hired','rejected','withdrew','blacklisted')),

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);
create index on candidates(tenant_id, status);
create index candidates_name_trgm on candidates using gin
  ((first_name_en || ' ' || last_name_en) gin_trgm_ops);

-- A candidate's application to a specific requisition.
-- The full recruitment funnel lives here.
create type interview_outcome as enum ('pass','fail','on_hold','no_show','pending');

create table candidate_applications (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  candidate_id  uuid not null references candidates(id) on delete cascade,
  requisition_id uuid not null references staff_requisitions(id) on delete cascade,
  source_id     uuid references candidate_sources(id),

  apply_date    date not null,
  current_stage text not null default 'applied' check (current_stage in (
    'applied','hr_screening','phone_interview','first_interview',
    'second_interview','hm_review','reference_check',
    'offer','hired','rejected','withdrawn'
  )),

  -- HR Screening
  hr_screen_result interview_outcome,
  hr_screen_comment text,
  hr_screen_at  timestamptz,

  -- Phone interview
  phone_interview_date timestamptz,
  phone_interview_result interview_outcome,
  phone_interview_comment text,

  -- 1st interview
  first_interview_at timestamptz,
  first_interview_room text,
  first_interview_result interview_outcome,
  first_interview_hm_summary text,
  first_interview_hm_summary_at timestamptz,

  -- 2nd interview
  second_interview_at timestamptz,
  second_interview_room text,
  second_interview_result interview_outcome,
  second_interview_hm_summary text,
  second_interview_hm_summary_at timestamptz,

  -- Hiring manager review
  hm_review_result interview_outcome,
  hm_review_at  timestamptz,
  hm_review_comment text,
  hm_comment_before_interview text,
  hm_screen_comment text,

  -- Reference check
  reference_check_status text check (reference_check_status in ('pending','in_progress','passed','failed','skipped')),
  reference_check_notes text,

  -- Job offer
  offer_status  text check (offer_status in ('pending','offered','accepted','declined','rescinded')),
  offer_made_at timestamptz,
  offer_response_at timestamptz,
  offer_start_date date,
  offer_decline_reason text,

  -- Outcome
  final_outcome text check (final_outcome in ('hired','rejected','withdrew','no_show','on_hold')),
  unqualified_reason text,
  unqualified_reason_hm text,

  notes         text,
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (candidate_id, requisition_id)
);
create index on candidate_applications(tenant_id, current_stage);
create index on candidate_applications(requisition_id);


-- =====================================================================
-- 11. PROJECTS (Kaizen / Improvement initiatives) — v1 lightweight
-- =====================================================================

create type project_status as enum ('proposed','approved','in_progress','on_hold','completed','cancelled');

create table projects (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  code          text not null,                          -- ProjectCode
  name          text not null,                          -- ProjectName
  purpose       text,                                   -- ProjectPurpose
  leader_employee_id uuid references employees(id),
  advisor_employee_id uuid references employees(id),
  due_date      date,                                   -- ProjectDueDate
  status        project_status not null default 'proposed',
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, code)
);

create table project_members (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  project_id    uuid not null references projects(id) on delete cascade,
  employee_id   uuid not null references employees(id),
  member_code   text,                                   -- ProjectMemberCode
  role_in_project text,
  issue_date    date,                                   -- ProjectMemberIssueDate
  status        text default 'active' check (status in ('active','removed','completed')),
  unique (project_id, employee_id)
);

create table project_topics (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  project_id    uuid not null references projects(id) on delete cascade,
  topic         text not null,
  description   text,
  sequence      int default 1,
  created_at    timestamptz not null default now()
);

create table project_individual_topics (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  project_topic_id uuid not null references project_topics(id) on delete cascade,
  employee_id   uuid not null references employees(id),
  status        text default 'open',
  created_at    timestamptz not null default now()
);

create table project_individual_items (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  project_individual_topic_id uuid not null references project_individual_topics(id) on delete cascade,
  item_name_en  text,
  item_name_th  text,
  status        text default 'open',
  due_date      date,
  completed_at  timestamptz,
  created_at    timestamptz not null default now()
);


-- =====================================================================
-- 12. AUDIT LOG (cross-cutting)
-- =====================================================================

create table audit_log (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id),
  actor_profile_id uuid references profiles(id),
  actor_employee_id uuid references employees(id),
  action        text not null,                          -- "wi.published", "skill.certified", "employee.transferred"
  entity_type   text not null,                          -- table name or logical type
  entity_id     uuid,
  details       jsonb default '{}',
  ip_address    inet,
  user_agent    text,
  occurred_at   timestamptz not null default now()
);
create index on audit_log(tenant_id, occurred_at desc);
create index on audit_log(tenant_id, entity_type, entity_id);


-- =====================================================================
-- 13. NOTIFICATIONS (for skill expiry, approvals, etc.)
-- =====================================================================

create table notifications (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id),
  recipient_profile_id uuid references profiles(id),
  recipient_employee_id uuid references employees(id),
  kind          text not null,                          -- "skill_expiring", "approval_required", "wi_published"
  title         text not null,
  body          text,
  link_url      text,
  data          jsonb default '{}',
  read_at       timestamptz,
  created_at    timestamptz not null default now()
);
create index on notifications(recipient_profile_id, read_at) where read_at is null;


-- =====================================================================
-- 14. UPDATED_AT TRIGGERS
-- =====================================================================

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Apply to every table that has updated_at
do $$
declare t text;
begin
  for t in
    select table_name from information_schema.columns
    where column_name = 'updated_at' and table_schema = 'public'
  loop
    execute format(
      'drop trigger if exists set_updated_at on %I;
       create trigger set_updated_at before update on %I
       for each row execute function set_updated_at();',
      t, t
    );
  end loop;
end$$;


-- =====================================================================
-- 15. ROW LEVEL SECURITY (RLS) — Tenant isolation
-- =====================================================================
-- Pattern: every business table has tenant_id; RLS policy filters by current user's tenants.

-- Helper: returns current user's tenant IDs (cached per request)
create or replace function current_tenant_ids()
returns setof uuid
language sql
stable
security definer
as $$
  select tenant_id from tenant_members
   where profile_id = auth.uid() and status = 'active'
$$;

-- Enable RLS on all tenant-scoped tables
do $$
declare t text;
begin
  for t in
    select table_name from information_schema.columns
    where column_name = 'tenant_id' and table_schema = 'public'
  loop
    execute format('alter table %I enable row level security;', t);
    execute format(
      'drop policy if exists tenant_isolation on %I;
       create policy tenant_isolation on %I
       using (tenant_id in (select current_tenant_ids()));',
      t, t, t
    );
  end loop;
end$$;

-- Special: tenants table itself
alter table tenants enable row level security;
create policy tenant_self_visibility on tenants
  using (id in (select current_tenant_ids()));

-- Special: profiles table (users see only their own profile)
alter table profiles enable row level security;
create policy profile_self on profiles
  using (id = auth.uid());


-- =====================================================================
-- 16. SEED DATA: system permissions
-- =====================================================================
insert into permissions (code, module, description) values
  -- Training
  ('wi.read',                 'training',    'View Work Instructions'),
  ('wi.create',               'training',    'Create new Work Instructions'),
  ('wi.update',               'training',    'Edit existing Work Instructions'),
  ('wi.publish',              'training',    'Publish/archive Work Instructions'),
  ('skill.read_own',          'training',    'View own skill record'),
  ('skill.read_all',          'training',    'View all employees skill matrix'),
  ('skill.certify',           'training',    'Certify or re-certify a skill (RAD level 2)'),
  ('skill.set_practicing',    'training',    'Move a skill to practicing (RAD level 1)'),
  ('skill.revoke',            'training',    'Revoke a skill certification'),
  ('tr.create',               'training',    'Create a training record'),
  ('tr.update',               'training',    'Update a training record'),
  -- People
  ('employees.read',          'people',      'View employees'),
  ('employees.create',        'people',      'Add new employees'),
  ('employees.update',        'people',      'Edit employees'),
  ('employees.terminate',     'people',      'Terminate or resign employees'),
  ('subcontract.read',        'people',      'View subcontract workers and agencies'),
  ('subcontract.manage',      'people',      'Manage subcontract workers, requests, budgets'),
  -- Quality
  ('defects.read',            'quality',     'View defect log'),
  ('defects.create',          'quality',     'Create defect entries'),
  ('defects.close',           'quality',     'Close defects'),
  -- Safety
  ('ppe.read',                'safety',      'View PPE catalog and issuance log'),
  ('ppe.issue',               'safety',      'Issue PPE to workers'),
  -- HR
  ('hr.assessment_run',       'hr',          'Run annual JD assessment cycle'),
  ('hr.transfers_approve',    'hr',          'Approve transfer requests'),
  ('hr.resignation_approve',  'hr',          'Approve resignation requests'),
  -- Recruitment (v2)
  ('recruitment.read',        'recruitment', 'View recruitment pipeline'),
  ('recruitment.manage',      'recruitment', 'Manage requisitions, candidates, interviews'),
  -- Admin
  ('tenant.settings',         'admin',       'Manage tenant settings'),
  ('tenant.billing',          'admin',       'Manage billing and plan'),
  ('users.invite',            'admin',       'Invite users to tenant'),
  ('users.assign_role',       'admin',       'Assign roles to tenant members'),
  ('audit.read',              'admin',       'Read audit log'),
  -- Reports
  ('reports.run',             'reports',     'Run and export reports')
on conflict (code) do update set
  module = excluded.module,
  description = excluded.description;


-- =====================================================================
-- END
-- =====================================================================
-- Next steps:
-- 1. Apply this in a Supabase project
-- 2. Add seed data for default roles per new tenant
-- 3. Add storage buckets for: photos, wi-attachments, evidence
-- 4. Add Edge Functions for: skill_expiry_scan, send_notifications
-- 5. Iterate after Tanawat reviews + Excel arrives (may need column adjustments)
-- =====================================================================
