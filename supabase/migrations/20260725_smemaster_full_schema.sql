-- CLIVORA SMEMaster program — reproducible consolidated schema (DB-001)
-- Full schema snapshot
-- on 2026-07-25. This file supersedes the comment-only stubs:
--   20260724_phase0_foundations.sql, 20260724_phase1_crm_enrichment.sql,
--   20260724_phases_2_9_program.sql, 20260724_automation_queue_rls.sql,
--   20260725_protect_profiles_privileged.sql, 20260725_vault_share_public_lookup.sql
--
-- It is idempotent: safe to run on a clean database and re-run on an existing one.
-- No secrets or customer data are embedded. Money stays additive (*_minor dual-write).
-- Depends on pre-existing objects: public.profiles, public.crm_customers,
-- public.crm_projects, public.project_shares, public.is_admin(), public.my_email().

begin;

-- ---------------------------------------------------------------------------
-- Phase 1: CRM enrichment — additive columns on crm_customers
-- ---------------------------------------------------------------------------
alter table public.crm_customers
  add column if not exists company_id uuid,
  add column if not exists lead_score integer not null default 0,
  add column if not exists next_action text,
  add column if not exists next_action_at timestamptz,
  add column if not exists duplicate_of uuid;

-- ---------------------------------------------------------------------------
-- CRM companies / tags / groups / segments / activities + link tables
-- ---------------------------------------------------------------------------
create table if not exists public.crm_companies (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  name text not null,
  website text,
  industry text,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists crm_companies_owner_idx on public.crm_companies (owner_uid, updated_at desc);

create table if not exists public.crm_tags (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color text not null default '#64748b',
  created_at timestamptz not null default now(),
  unique (owner_uid, name)
);

create table if not exists public.crm_groups (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text not null default '',
  created_at timestamptz not null default now(),
  unique (owner_uid, name)
);

create table if not exists public.crm_segments (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  name text not null,
  definition jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_uid, name)
);

create table if not exists public.crm_activities (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  customer_id uuid references public.crm_customers(id) on delete cascade,
  company_id uuid references public.crm_companies(id) on delete set null,
  activity_type text not null default 'note'
    check (activity_type in ('note','call','email','meeting','status_change','task','system')),
  title text not null default '',
  body text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists crm_activities_customer_idx on public.crm_activities (customer_id, occurred_at desc);
create index if not exists crm_activities_owner_idx on public.crm_activities (owner_uid, occurred_at desc);

create table if not exists public.crm_customer_tags (
  customer_id uuid not null references public.crm_customers(id) on delete cascade,
  tag_id uuid not null references public.crm_tags(id) on delete cascade,
  primary key (customer_id, tag_id)
);

create table if not exists public.crm_customer_groups (
  customer_id uuid not null references public.crm_customers(id) on delete cascade,
  group_id uuid not null references public.crm_groups(id) on delete cascade,
  primary key (customer_id, group_id)
);

-- crm_customers.company_id FK (added after crm_companies exists)
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'crm_customers_company_id_fkey'
  ) then
    alter table public.crm_customers
      add constraint crm_customers_company_id_fkey
      foreign key (company_id) references public.crm_companies(id) on delete set null;
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'crm_customers_duplicate_of_fkey'
  ) then
    alter table public.crm_customers
      add constraint crm_customers_duplicate_of_fkey
      foreign key (duplicate_of) references public.crm_customers(id) on delete set null;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Phase 2: workspace_tasks
-- ---------------------------------------------------------------------------
create table if not exists public.workspace_tasks (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  local_id integer,
  project_id uuid references public.crm_projects(id) on delete set null,
  customer_id uuid references public.crm_customers(id) on delete set null,
  title text not null,
  description text not null default '',
  priority text not null default 'medium',
  status text not null default 'pending',
  due_at timestamptz,
  completed boolean not null default false,
  recurrence_rule text,
  parent_task_id uuid references public.workspace_tasks(id) on delete cascade,
  is_milestone boolean not null default false,
  shared_with_uid uuid references auth.users(id) on delete set null,
  project_share_id text references public.project_shares(share_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_uid, local_id)
);
create index if not exists workspace_tasks_owner_idx on public.workspace_tasks (owner_uid, updated_at desc);
create index if not exists workspace_tasks_shared_idx on public.workspace_tasks (shared_with_uid, updated_at desc);

-- ---------------------------------------------------------------------------
-- Phase 3: calendar_events
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  local_id integer,
  project_id uuid references public.crm_projects(id) on delete set null,
  customer_id uuid references public.crm_customers(id) on delete set null,
  title text not null,
  description text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text not null default '',
  meeting_link_id uuid,
  all_day boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_uid, local_id)
);
create index if not exists calendar_events_owner_idx on public.calendar_events (owner_uid, starts_at);

-- ---------------------------------------------------------------------------
-- Phase 4: crm_sync_conflicts
-- ---------------------------------------------------------------------------
create table if not exists public.crm_sync_conflicts (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  entity_type text not null
    check (entity_type in ('customer','project','invoice','task','activity','company')),
  entity_id uuid,
  local_id integer,
  local_snapshot jsonb not null default '{}'::jsonb,
  cloud_snapshot jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (status in ('open','resolved','dismissed')),
  resolution text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists crm_sync_conflicts_owner_idx on public.crm_sync_conflicts (owner_uid, status, created_at desc);

-- ---------------------------------------------------------------------------
-- Phase 6: campaigns + blocks + templates
-- ---------------------------------------------------------------------------
create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  title text not null,
  status text not null default 'draft'
    check (status in ('draft','scheduled','publishing','published','failed')),
  platform text not null default 'connect',
  preview_html text not null default '',
  ab_variant text check (ab_variant is null or ab_variant in ('A','B')),
  published_at timestamptz,
  fail_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists campaigns_owner_idx on public.campaigns (owner_uid, updated_at desc);

create table if not exists public.campaign_blocks (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  sort_order integer not null default 0,
  block_type text not null default 'text',
  content jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.campaign_templates (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  name text not null,
  blocks jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique (owner_uid, name)
);

-- ---------------------------------------------------------------------------
-- Phase 7: automation_rules
-- ---------------------------------------------------------------------------
create table if not exists public.automation_rules (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  name text not null,
  enabled boolean not null default false,
  trigger_type text not null,
  trigger_config jsonb not null default '{}'::jsonb,
  action_type text not null,
  action_config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Phase 8: ai_suggestions
-- ---------------------------------------------------------------------------
create table if not exists public.ai_suggestions (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  entity_type text not null,
  entity_id uuid,
  suggestion_type text not null default 'summary',
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending_review'
    check (status in ('pending_review','accepted','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint ai_suggestions_no_auto_pay
    check (suggestion_type <> all (array['auto_pay','auto_publish']))
);

-- ---------------------------------------------------------------------------
-- Phase 0/5: vault tables + idempotency + audit
-- ---------------------------------------------------------------------------
create table if not exists public.vault_attachments (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  entity_type text not null default 'file',
  entity_id text,
  storage_bucket text not null default 'project-files',
  storage_path text not null,
  file_name text not null default '',
  mime_type text,
  size_bytes bigint not null default 0,
  checksum text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists vault_attachments_owner_idx on public.vault_attachments (owner_uid, created_at desc);

create table if not exists public.vault_share_links (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  storage_path text,
  file_path text,
  file_id text,
  file_name text not null default '',
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  expires_at timestamptz not null,
  max_downloads integer,
  download_count integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  scope text not null,
  key text not null,
  request_hash text,
  response jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (owner_uid, scope, key)
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_uid uuid references auth.users(id) on delete set null,
  workspace_uid uuid,
  action text not null,
  entity_type text not null,
  entity_id text,
  payload jsonb not null default '{}'::jsonb,
  ip inet,
  user_agent text,
  created_at timestamptz not null default now()
);
create index if not exists audit_events_actor_idx on public.audit_events (actor_uid, created_at desc);
create index if not exists audit_events_workspace_idx on public.audit_events (workspace_uid, created_at desc);

-- ---------------------------------------------------------------------------
-- Money dual-write (additive minor-unit columns; numeric stays source until cutover)
-- ---------------------------------------------------------------------------
alter table public.crm_invoices
  add column if not exists subtotal_minor bigint,
  add column if not exists tax_minor bigint,
  add column if not exists discount_minor bigint,
  add column if not exists total_minor bigint,
  add column if not exists amount_paid_minor bigint;
alter table public.invoice_shares add column if not exists total_minor bigint;
alter table public.quote_shares add column if not exists total_minor bigint;

-- ---------------------------------------------------------------------------
-- RLS enable
-- ---------------------------------------------------------------------------
alter table public.crm_companies enable row level security;
alter table public.crm_tags enable row level security;
alter table public.crm_groups enable row level security;
alter table public.crm_segments enable row level security;
alter table public.crm_activities enable row level security;
alter table public.crm_customer_tags enable row level security;
alter table public.crm_customer_groups enable row level security;
alter table public.workspace_tasks enable row level security;
alter table public.calendar_events enable row level security;
alter table public.crm_sync_conflicts enable row level security;
alter table public.campaigns enable row level security;
alter table public.campaign_blocks enable row level security;
alter table public.campaign_templates enable row level security;
alter table public.automation_rules enable row level security;
alter table public.ai_suggestions enable row level security;
alter table public.vault_attachments enable row level security;
alter table public.vault_share_links enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.audit_events enable row level security;

-- ---------------------------------------------------------------------------
-- RLS policies (owner-scoped; admin override via is_admin())
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
  owner_tables text[] := array[
    'crm_companies','crm_tags','crm_groups','crm_segments','crm_activities',
    'workspace_tasks','calendar_events','crm_sync_conflicts','campaigns',
    'campaign_templates','automation_rules','ai_suggestions','vault_attachments',
    'vault_share_links','idempotency_keys'
  ];
begin
  foreach t in array owner_tables loop
    execute format('drop policy if exists %I on public.%I', t || '_owner', t);
  end loop;
end $$;

create policy crm_companies_owner on public.crm_companies for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy crm_tags_owner on public.crm_tags for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy crm_groups_owner on public.crm_groups for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy crm_segments_owner on public.crm_segments for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy crm_activities_owner on public.crm_activities for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy calendar_events_owner on public.calendar_events for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy crm_sync_conflicts_owner on public.crm_sync_conflicts for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy campaigns_owner on public.campaigns for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy campaign_templates_owner on public.campaign_templates for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy automation_rules_owner on public.automation_rules for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy ai_suggestions_owner on public.ai_suggestions for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy vault_attachments_owner on public.vault_attachments for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy vault_share_owner on public.vault_share_links for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());
create policy idempotency_keys_owner on public.idempotency_keys for all to authenticated
  using (owner_uid = auth.uid() or is_admin()) with check (owner_uid = auth.uid() or is_admin());

create policy workspace_tasks_owner on public.workspace_tasks for all to authenticated
  using (owner_uid = auth.uid() or shared_with_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists campaign_blocks_owner on public.campaign_blocks;
create policy campaign_blocks_owner on public.campaign_blocks for all to authenticated
  using (is_admin() or exists (select 1 from public.campaigns c where c.id = campaign_id and c.owner_uid = auth.uid()))
  with check (is_admin() or exists (select 1 from public.campaigns c where c.id = campaign_id and c.owner_uid = auth.uid()));

drop policy if exists crm_customer_tags_owner on public.crm_customer_tags;
create policy crm_customer_tags_owner on public.crm_customer_tags for all to authenticated
  using (is_admin() or exists (select 1 from public.crm_customers c where c.id = customer_id and c.owner_uid = auth.uid()))
  with check (is_admin() or exists (select 1 from public.crm_customers c where c.id = customer_id and c.owner_uid = auth.uid()));

drop policy if exists crm_customer_groups_owner on public.crm_customer_groups;
create policy crm_customer_groups_owner on public.crm_customer_groups for all to authenticated
  using (is_admin() or exists (select 1 from public.crm_customers c where c.id = customer_id and c.owner_uid = auth.uid()))
  with check (is_admin() or exists (select 1 from public.crm_customers c where c.id = customer_id and c.owner_uid = auth.uid()));

drop policy if exists audit_events_admin_select on public.audit_events;
create policy audit_events_admin_select on public.audit_events for select to authenticated
  using (is_admin() or actor_uid = auth.uid() or workspace_uid = auth.uid());

-- ---------------------------------------------------------------------------
-- Functions / RPCs (SECURITY DEFINER, pinned search_path)
-- ---------------------------------------------------------------------------
create or replace function public.write_audit_event(
  p_action text, p_entity_type text, p_entity_id text default null,
  p_workspace_uid uuid default null, p_payload jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path to 'public' as $fn$
declare v_id uuid;
begin
  insert into public.audit_events(actor_uid, workspace_uid, action, entity_type, entity_id, payload)
  values (auth.uid(), coalesce(p_workspace_uid, auth.uid()), p_action, p_entity_type, p_entity_id, coalesce(p_payload, '{}'::jsonb))
  returning id into v_id;
  return v_id;
end;
$fn$;

create or replace function public.crm_recompute_lead_score(p_customer_id uuid)
returns integer language plpgsql security definer set search_path to 'public' as $fn$
declare c record; score int := 0; email_count int := 0; phone_count int := 0;
begin
  select * into c from public.crm_customers where id = p_customer_id;
  if not found then return 0; end if;
  if c.owner_uid is distinct from auth.uid() and not public.is_admin() then
    raise exception 'not authorized';
  end if;
  email_count := coalesce(jsonb_array_length(c.emails), 0);
  phone_count := coalesce(jsonb_array_length(c.phones), 0);
  if email_count > 0 then score := score + 20; end if;
  if phone_count > 0 then score := score + 15; end if;
  if coalesce(c.company, '') <> '' or c.company_id is not null then score := score + 15; end if;
  if coalesce(c.notes, '') <> '' then score := score + 10; end if;
  if lower(coalesce(c.status, '')) in ('active','lead','qualified') then score := score + 20; end if;
  if exists (select 1 from public.crm_projects p where p.customer_id = c.id) then score := score + 20; end if;
  score := least(100, score);
  update public.crm_customers set lead_score = score, updated_at = now() where id = c.id;
  return score;
end;
$fn$;

create or replace function public.crm_find_duplicate_customers(p_customer_id uuid)
returns table(id uuid, contact_person text, company text, score integer)
language plpgsql security definer set search_path to 'public' as $fn$
declare c record;
begin
  select * into c from public.crm_customers where crm_customers.id = p_customer_id;
  if not found then return; end if;
  if c.owner_uid is distinct from auth.uid() and not public.is_admin() then
    raise exception 'not authorized';
  end if;
  return query
  select o.id, o.contact_person, o.company,
    (
      case when lower(coalesce(o.contact_person,'')) = lower(coalesce(c.contact_person,'')) and coalesce(c.contact_person,'') <> '' then 50 else 0 end
      + case when lower(coalesce(o.company,'')) = lower(coalesce(c.company,'')) and coalesce(c.company,'') <> '' then 30 else 0 end
      + case when o.emails ?| array(select jsonb_array_elements_text(coalesce(c.emails, '[]'::jsonb))) then 40 else 0 end
    )::int as score
  from public.crm_customers o
  where o.owner_uid = c.owner_uid and o.id <> c.id and o.duplicate_of is null
  order by 4 desc limit 10;
end;
$fn$;

create or replace function public.profiles_protect_privileged_columns()
returns trigger language plpgsql security definer set search_path to 'public' as $fn$
begin
  if public.is_admin() then return new; end if;
  if new.role is distinct from old.role then raise exception 'cannot change role'; end if;
  if new.account_type is distinct from old.account_type
     and old.account_type is not null and old.account_type <> '' then
    raise exception 'cannot change account_type';
  end if;
  if new.is_blocked is distinct from old.is_blocked then raise exception 'cannot change is_blocked'; end if;
  if new.is_restricted is distinct from old.is_restricted then raise exception 'cannot change is_restricted'; end if;
  if new.subscription_plan is distinct from old.subscription_plan then raise exception 'cannot change subscription_plan'; end if;
  return new;
end;
$fn$;

drop trigger if exists profiles_protect_privileged_columns_trg on public.profiles;
create trigger profiles_protect_privileged_columns_trg
  before update on public.profiles
  for each row execute function public.profiles_protect_privileged_columns();

create or replace function public.vault_lookup_share_by_token(p_token text)
returns table(id uuid, file_name text, storage_path text, expires_at timestamptz, max_downloads integer, download_count integer)
language plpgsql security definer set search_path to 'public' as $fn$
begin
  return query
  select v.id, v.file_name, v.storage_path, v.expires_at, v.max_downloads, v.download_count
  from public.vault_share_links v where v.token = p_token limit 1;
end;
$fn$;

revoke all on function public.crm_recompute_lead_score(uuid) from public;
revoke all on function public.crm_find_duplicate_customers(uuid) from public;
revoke all on function public.vault_lookup_share_by_token(text) from public;
grant execute on function public.crm_recompute_lead_score(uuid) to authenticated;
grant execute on function public.crm_find_duplicate_customers(uuid) to authenticated;
grant execute on function public.vault_lookup_share_by_token(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Feature flags: register keys only; ENABLEMENT IS NOT SET HERE.
-- Flag truth (on/off) is managed via the audited admin flag procedure, not migrations.
-- ---------------------------------------------------------------------------
insert into public.app_feature_flags (key, enabled) values
  ('phase0_foundations', false),
  ('money_minor_units_dual_write', false),
  ('crm_enrichment', false),
  ('workspace_tasks', false),
  ('calendar_events', false),
  ('crm_conflict_ui', false),
  ('vault_cloud', false),
  ('campaigns', false),
  ('campaigns_ab_testing', false),
  ('automation_builder', false),
  ('ai_structured', false),
  ('admin_ops_dashboard', false),
  ('phase1_crm_enrichment', false),
  ('phase2_workspace_tasks', false),
  ('phase3_calendar_events', false),
  ('phase4_crm_conflicts', false),
  ('phase5_vault_cloud', false),
  ('phase6_campaigns', false),
  ('phase7_automation_builder', false),
  ('phase8_ai_structured', false),
  ('phase9_admin_ops', false)
on conflict (key) do nothing;

commit;
