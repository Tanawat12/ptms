-- ============================================================================
-- PTMS — SCHEMA V3 ADDITIONS (final v1 schema)
-- ============================================================================
-- Date:    2026-05-14
-- Purpose: Final additions based on Tanawat's answers to 14 design questions
--          from 9-PDF legacy UI review.
--
-- This is layered on top of NEW-SCHEMA.sql + SCHEMA-V2-ADDITIONS.sql.
--
-- WHAT'S NEW IN V3
--   1. Rotation Cap configuration (per-tenant threshold)
--   2. Per-WI Expected count (target Level 2 workers)
--   3. Cross-area helper tracking (⭐ star)
--   4. Skill record next-review date
--   5. Online KRS test invitations (mobile-friendly)
--   6. Auto-generated certificates with QR verification
--   7. Default position level seed for new tenants
-- ============================================================================


-- =====================================================================
-- 1. ROTATION CAP CONFIGURATION
-- =====================================================================

alter table tenants
  add column if not exists rotation_cap_threshold int not null default 90
    check (rotation_cap_threshold between 0 and 100),
  add column if not exists rotation_cap_review_cadence text default 'quarterly'
    check (rotation_cap_review_cadence in ('monthly','quarterly','semi_annual','annual','custom'));


-- =====================================================================
-- 2. PER-WI EXPECTED COUNT
-- =====================================================================

alter table work_instructions
  add column if not exists expected_level_2_count int default 0,
  add column if not exists expected_set_by_employee_id uuid references employees(id),
  add column if not exists expected_set_at timestamptz,
  add column if not exists expected_next_review_date date,
  add column if not exists expected_review_notes text;

-- History of "Expected" adjustments (for audit + trend analysis)
create table wi_expected_history (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  wi_id         uuid not null references work_instructions(id) on delete cascade,
  previous_count int,
  new_count     int not null,
  changed_by_employee_id uuid references employees(id),
  change_reason text,
  changed_at    timestamptz not null default now()
);
create index on wi_expected_history(wi_id, changed_at desc);


-- =====================================================================
-- 3. CROSS-AREA HELPERS (⭐)
-- =====================================================================

-- Add home vs workplace area to skill_records
alter table skill_records
  add column if not exists home_org_node_id uuid references org_nodes(id),
  add column if not exists workplace_org_node_id uuid references org_nodes(id),
  add column if not exists next_review_date date;

-- Derived: is this person a cross-area helper for this WI?
-- (their home area differs from where this WI lives)
-- Note: don't use STORED generated for FK-referenced columns; use a view instead

create or replace view v_skill_records_with_helper_flag as
select
  sr.*,
  case
    when sr.home_org_node_id is not null
     and sr.workplace_org_node_id is not null
     and sr.home_org_node_id != sr.workplace_org_node_id
    then true
    else false
  end as is_cross_area_helper
from skill_records sr;


-- =====================================================================
-- 4. ONLINE KRS TEST INVITATIONS (NEW v1 feature)
-- =====================================================================
-- Workers can take the KRS test on any device via a personal link.
-- During the test, only questions + choices visible (NOT answers).
-- After submission, score + correct answers shown (if pass).
-- Result auto-flows into OJA assessment as test_score.

create type test_invitation_status as enum (
  'created','sent','opened','in_progress','submitted','expired','cancelled'
);

create type test_send_channel as enum ('email','sms','line','manual','qr');

create table krs_test_invitations (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  wi_id         uuid not null references work_instructions(id) on delete restrict,

  -- Who's taking the test
  employee_id   uuid references employees(id),
  subcontract_worker_id uuid references subcontract_workers(id),

  -- Auth token (the URL hash) - random 32+ chars, immutable
  invite_token  text unique not null,

  -- Lifecycle
  status        test_invitation_status not null default 'created',
  sent_via      test_send_channel,
  sent_to       text,                                 -- email or phone the link went to
  sent_at       timestamptz,
  opened_at     timestamptz,
  started_at    timestamptz,
  submitted_at  timestamptz,
  expires_at    timestamptz not null,                 -- usually 7 days

  -- Results (filled when submitted)
  total_questions int,
  correct_answers int,
  score_percent numeric(5,2),
  passed        boolean,                              -- score >= pass_threshold
  pass_threshold int default 80,                      -- override per invitation if needed
  time_taken_seconds int,

  -- Tied to an OJA assessment if applicable
  oja_assessment_id uuid references oja_assessments(id),

  -- Audit
  created_by_employee_id uuid references employees(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  check (employee_id is not null or subcontract_worker_id is not null)
);
create index on krs_test_invitations(tenant_id);
create index on krs_test_invitations(invite_token);
create index on krs_test_invitations(employee_id) where employee_id is not null;
create index on krs_test_invitations(subcontract_worker_id) where subcontract_worker_id is not null;
create index on krs_test_invitations(wi_id);

-- Answers given for each invitation
create table krs_test_invitation_answers (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  invitation_id uuid not null references krs_test_invitations(id) on delete cascade,
  wi_test_question_id uuid not null references wi_test_questions(id) on delete restrict,
  given_answer  text,
  is_correct    boolean,
  answered_at   timestamptz default now(),
  unique (invitation_id, wi_test_question_id)
);
create index on krs_test_invitation_answers(invitation_id);


-- =====================================================================
-- 5. AUTO-GENERATED CERTIFICATES (v1 MUST HAVE)
-- =====================================================================
-- Triggered when:
--   - Worker reaches Level 2 on a WI (oja_assessments.rad_level_awarded = '2')
--   - Worker completes a classroom training (training_record_attendees.result = 'pass')
--   - Worker completes annual JD assessment
-- Output: PDF in Supabase Storage with QR code for public verification.

create type certificate_type as enum (
  'wi_certification',           -- Level 2 on a WI
  'training_completion',        -- Classroom training pass
  'annual_assessment',          -- JD assessment finalized
  'safety_training',
  'orientation',
  'custom'
);

create table certificates (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  cert_no       text not null,                       -- e.g., "CERT-2026-00001"
  cert_type     certificate_type not null,
  title         text not null,                       -- "Certified: 22CT-PICKLING-MACHINE"

  -- One of these (depending on type)
  skill_record_id uuid references skill_records(id),
  oja_assessment_id uuid references oja_assessments(id),
  training_record_attendee_id uuid references training_record_attendees(id),
  jd_assessment_id uuid references jd_assessments(id),

  -- Recipient
  employee_id   uuid references employees(id),
  subcontract_worker_id uuid references subcontract_workers(id),

  -- Issuer
  issued_by_employee_id uuid references employees(id),
  issued_at     timestamptz not null default now(),
  valid_until   date,                                -- null if no expiry

  -- Files (Supabase Storage)
  pdf_url       text not null,
  qr_code_url   text,
  preview_image_url text,

  -- Public verification
  verification_token text unique not null,           -- the slug behind QR code
  verification_url text generated always as (
    'https://ptms.app/verify/' || verification_token
  ) stored,

  -- Revocation
  is_revoked    boolean default false,
  revoked_at    timestamptz,
  revoked_by_employee_id uuid references employees(id),
  revoked_reason text,

  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  check (employee_id is not null or subcontract_worker_id is not null),
  unique (tenant_id, cert_no)
);
create index on certificates(tenant_id);
create index on certificates(verification_token);
create index on certificates(employee_id) where employee_id is not null;
create index on certificates(subcontract_worker_id) where subcontract_worker_id is not null;

-- Certificate template per tenant (branding)
create table certificate_templates (
  id            uuid primary key default uuid_generate_v4(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  cert_type     certificate_type not null,
  template_name text not null,
  is_default    boolean default false,
  logo_url      text,
  primary_color text default '#1E40AF',
  secondary_color text default '#FFFFFF',
  background_image_url text,
  signature_image_url text,                          -- pre-signed by authorized person
  signed_by_name text,
  signed_by_title text,
  header_text   text,
  footer_text   text,
  custom_css    text,
  template_html text,                                -- Handlebars-like template
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, cert_type, template_name)
);


-- =====================================================================
-- 6. DEFAULT POSITION LEVELS (seed function)
-- =====================================================================
-- Function that seeds the default 9-level hierarchy for a new tenant.
-- Called from the tenant signup flow.

create or replace function seed_default_position_levels(p_tenant_id uuid)
returns void as $$
begin
  insert into position_levels (tenant_id, code, name_en, name_th, rank) values
    (p_tenant_id, 'SUBCON',  'Subcontract Worker', 'พนักงานเหมาช่วง', 1),
    (p_tenant_id, 'WORKER',  'Worker',             'พนักงาน',         2),
    (p_tenant_id, 'LEADER',  'Leader / Supervisor', 'หัวหน้างาน',     3),
    (p_tenant_id, 'MGR',     'Manager',            'ผู้จัดการ',         4),
    (p_tenant_id, 'SR_MGR',  'Senior Manager',     'ผู้จัดการอาวุโส',     5),
    (p_tenant_id, 'GM',      'General Manager',    'ผู้จัดการทั่วไป',     6),
    (p_tenant_id, 'VP',      'Vice President',     'รองประธาน',        7),
    (p_tenant_id, 'EVP',     'Executive VP',       'รองประธานบริหาร',   8),
    (p_tenant_id, 'CEO',     'CEO',                'ประธานกรรมการ',   9)
  on conflict (tenant_id, code) do nothing;
end;
$$ language plpgsql security definer;


-- =====================================================================
-- 7. ROTATION CAP COMPUTED VIEW
-- =====================================================================
-- For each WI, compute: how many at Level 2, vs Expected, vs Rotation Cap %

create or replace view v_wi_rotation_status as
select
  wi.tenant_id,
  wi.id as wi_id,
  wi.code as wi_code,
  wi.name_en as wi_name,
  wi.org_node_id,
  wi.expected_level_2_count as expected,
  count(*) filter (
    where sr.status = 'certified' and sr.rad_level = '2'
  ) as level_2_count,
  count(*) filter (
    where sr.status = 'practicing' or sr.rad_level = '1'
  ) as level_1_count,
  count(*) filter (
    where sr.status = 'in_training' or sr.rad_level = '0'
  ) as being_trained_count,
  count(*) filter (where sr.status = 'expired') as expired_count,
  case
    when wi.expected_level_2_count > 0 then
      round(
        100.0 * count(*) filter (where sr.status = 'certified' and sr.rad_level = '2')
        / wi.expected_level_2_count,
        2
      )
    else null
  end as rotation_cap_percent,
  t.rotation_cap_threshold,
  case
    when wi.expected_level_2_count = 0 then 'no_target'
    when (100.0 * count(*) filter (where sr.status = 'certified' and sr.rad_level = '2')
          / nullif(wi.expected_level_2_count, 0)) >= t.rotation_cap_threshold
      then 'capable'
    else 'not_capable'
  end as rotation_capability_status
from work_instructions wi
join tenants t on wi.tenant_id = t.id
left join skill_records sr on sr.wi_id = wi.id
where wi.deleted_at is null
group by wi.tenant_id, wi.id, wi.code, wi.name_en, wi.org_node_id,
         wi.expected_level_2_count, t.rotation_cap_threshold;


-- =====================================================================
-- 8. SUB-AREA / DEPARTMENT / COMPANY ROLL-UP VIEWS
-- =====================================================================
-- For the multi-level drill-down UI

-- Sub-area roll-up (typically org_nodes.node_type = 'area')
create or replace view v_org_node_skill_rollup as
select
  o.tenant_id,
  o.id as org_node_id,
  o.code,
  o.name_en,
  o.parent_id,
  count(distinct wi.id) as wi_count,
  coalesce(sum(wi.expected_level_2_count), 0) as total_expected,
  coalesce(sum(rs.level_2_count), 0) as total_level_2,
  coalesce(sum(rs.level_1_count), 0) as total_level_1,
  coalesce(sum(rs.being_trained_count), 0) as total_being_trained,
  case
    when sum(wi.expected_level_2_count) > 0 then
      round(
        100.0 * sum(rs.level_2_count) / sum(wi.expected_level_2_count),
        2
      )
    else null
  end as overall_rotation_cap_percent
from org_nodes o
left join work_instructions wi on wi.org_node_id = o.id and wi.deleted_at is null
left join v_wi_rotation_status rs on rs.wi_id = wi.id
where o.deleted_at is null
group by o.tenant_id, o.id, o.code, o.name_en, o.parent_id;


-- =====================================================================
-- 9. RLS for all new tables
-- =====================================================================

do $$
declare t text;
declare new_tables text[] := array[
  'wi_expected_history','krs_test_invitations','krs_test_invitation_answers',
  'certificates','certificate_templates'
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
-- 10. New permissions
-- =====================================================================

insert into permissions (code, module, description) values
  ('rotation_cap.config',     'admin',       'Configure Rotation Cap threshold and review cadence'),
  ('wi.expected_set',         'training',    'Set/update Expected Level 2 count for a WI'),
  ('helper.assign',           'training',    'Mark worker as cross-area helper for a WI'),
  ('krs.invite_send',         'training',    'Send online KRS test invitation'),
  ('krs.invite_view',         'training',    'View KRS test invitation results'),
  ('certificate.issue',       'training',    'Issue certificates manually'),
  ('certificate.revoke',      'training',    'Revoke a previously issued certificate'),
  ('certificate.template',    'admin',       'Manage certificate templates and branding')
on conflict (code) do update set
  module = excluded.module,
  description = excluded.description;


-- =====================================================================
-- END OF SCHEMA V3 ADDITIONS
-- =====================================================================
-- Combined schema:
--   - NEW-SCHEMA.sql (v1):        38 tables (foundation)
--   - SCHEMA-V2-ADDITIONS.sql:    17 tables (WI sub-tables + OJA + catalogs)
--   - SCHEMA-V3-ADDITIONS.sql:    +5 tables, +5 columns, +3 views, +1 function
--   = TOTAL:                       60 tables, ~100% legacy coverage
-- =====================================================================
