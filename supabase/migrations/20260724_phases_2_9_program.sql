-- CLIVORA Phases 2–9 (additive, idempotent).
-- Exported from live Supabase (phases_2_9_smemaster_program).
-- See docs/internal/PHASES_2_9.md

begin;

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
    check (entity_type = any (array[
      'customer'::text, 'project'::text, 'invoice'::text,
      'task'::text, 'activity'::text, 'company'::text
    ])),
  entity_id uuid,
  local_id integer,
  local_snapshot jsonb not null default '{}'::jsonb,
  cloud_snapshot jsonb not null default '{}'::jsonb,
  status text not null default 'open'
    check (status = any (array['open'::text, 'resolved'::text, 'dismissed'::text])),
  resolution text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists crm_sync_conflicts_owner_idx
  on public.crm_sync_conflicts (owner_uid, status, created_at desc);

-- ---------------------------------------------------------------------------
-- Phase 6: campaigns + blocks + templates
-- ---------------------------------------------------------------------------
create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  title text not null,
  status text not null default 'draft'
    check (status = any (array[
      'draft'::text, 'scheduled'::text, 'publishing'::text,
      'published'::text, 'failed'::text
    ])),
  platform text not null default 'connect',
  preview_html text not null default '',
  ab_variant text check (ab_variant is null or ab_variant = any (array['A'::text, 'B'::text])),
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
    check (status = any (array['pending_review'::text, 'accepted'::text, 'rejected'::text])),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint ai_suggestions_no_auto_pay
    check (suggestion_type <> all (array['auto_pay'::text, 'auto_publish'::text]))
);

-- ---------------------------------------------------------------------------
-- crm_find_duplicate_customers()
-- ---------------------------------------------------------------------------
create or replace function public.crm_find_duplicate_customers(p_customer_id uuid)
returns table(id uuid, contact_person text, company text, score integer)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  c record;
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
  where o.owner_uid = c.owner_uid
    and o.id <> c.id
    and o.duplicate_of is null
  order by 4 desc
  limit 10;
end;
$function$;

revoke all on function public.crm_find_duplicate_customers(uuid) from public;
grant execute on function public.crm_find_duplicate_customers(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.workspace_tasks enable row level security;
alter table public.calendar_events enable row level security;
alter table public.crm_sync_conflicts enable row level security;
alter table public.campaigns enable row level security;
alter table public.campaign_blocks enable row level security;
alter table public.campaign_templates enable row level security;
alter table public.automation_rules enable row level security;
alter table public.ai_suggestions enable row level security;

drop policy if exists workspace_tasks_owner on public.workspace_tasks;
create policy workspace_tasks_owner on public.workspace_tasks
  for all to authenticated
  using (owner_uid = auth.uid() or shared_with_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists calendar_events_owner on public.calendar_events;
create policy calendar_events_owner on public.calendar_events
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists crm_sync_conflicts_owner on public.crm_sync_conflicts;
create policy crm_sync_conflicts_owner on public.crm_sync_conflicts
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists campaigns_owner on public.campaigns;
create policy campaigns_owner on public.campaigns
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists campaign_blocks_owner on public.campaign_blocks;
create policy campaign_blocks_owner on public.campaign_blocks
  for all to authenticated
  using (is_admin() or exists (
    select 1 from public.campaigns c
    where c.id = campaign_id and c.owner_uid = auth.uid()
  ))
  with check (is_admin() or exists (
    select 1 from public.campaigns c
    where c.id = campaign_id and c.owner_uid = auth.uid()
  ));

drop policy if exists campaign_templates_owner on public.campaign_templates;
create policy campaign_templates_owner on public.campaign_templates
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists automation_rules_owner on public.automation_rules;
create policy automation_rules_owner on public.automation_rules
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists ai_suggestions_owner on public.ai_suggestions;
create policy ai_suggestions_owner on public.ai_suggestions
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

-- ---------------------------------------------------------------------------
-- Feature-flag key registration (enablement NOT set here)
-- ---------------------------------------------------------------------------
insert into public.app_feature_flags (key, enabled) values
  ('workspace_tasks', false),
  ('calendar_events', false),
  ('crm_conflict_ui', false),
  ('campaigns', false),
  ('campaigns_ab_testing', false),
  ('automation_builder', false),
  ('ai_structured', false),
  ('admin_ops_dashboard', false),
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
