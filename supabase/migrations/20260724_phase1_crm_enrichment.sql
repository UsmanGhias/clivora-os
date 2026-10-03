-- CLIVORA Phase 1 CRM enrichment (additive, idempotent).
-- Exported from live Supabase (phase1_crm_enrichment).
-- See docs/internal/PHASE1_CRM_ENRICHMENT.md

begin;

-- ---------------------------------------------------------------------------
-- Additive columns on crm_customers
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
    check (activity_type = any (array[
      'note'::text, 'call'::text, 'email'::text, 'meeting'::text,
      'status_change'::text, 'task'::text, 'system'::text
    ])),
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

-- FKs on crm_customers (added after crm_companies exists)
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
-- crm_recompute_lead_score()
-- ---------------------------------------------------------------------------
create or replace function public.crm_recompute_lead_score(p_customer_id uuid)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  c record;
  score int := 0;
  email_count int := 0;
  phone_count int := 0;
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
$function$;

revoke all on function public.crm_recompute_lead_score(uuid) from public;
grant execute on function public.crm_recompute_lead_score(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.crm_companies enable row level security;
alter table public.crm_tags enable row level security;
alter table public.crm_groups enable row level security;
alter table public.crm_segments enable row level security;
alter table public.crm_activities enable row level security;
alter table public.crm_customer_tags enable row level security;
alter table public.crm_customer_groups enable row level security;

drop policy if exists crm_companies_owner on public.crm_companies;
create policy crm_companies_owner on public.crm_companies
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists crm_tags_owner on public.crm_tags;
create policy crm_tags_owner on public.crm_tags
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists crm_groups_owner on public.crm_groups;
create policy crm_groups_owner on public.crm_groups
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists crm_segments_owner on public.crm_segments;
create policy crm_segments_owner on public.crm_segments
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists crm_activities_owner on public.crm_activities;
create policy crm_activities_owner on public.crm_activities
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists crm_customer_tags_owner on public.crm_customer_tags;
create policy crm_customer_tags_owner on public.crm_customer_tags
  for all to authenticated
  using (is_admin() or exists (
    select 1 from public.crm_customers c
    where c.id = customer_id and c.owner_uid = auth.uid()
  ))
  with check (is_admin() or exists (
    select 1 from public.crm_customers c
    where c.id = customer_id and c.owner_uid = auth.uid()
  ));

drop policy if exists crm_customer_groups_owner on public.crm_customer_groups;
create policy crm_customer_groups_owner on public.crm_customer_groups
  for all to authenticated
  using (is_admin() or exists (
    select 1 from public.crm_customers c
    where c.id = customer_id and c.owner_uid = auth.uid()
  ))
  with check (is_admin() or exists (
    select 1 from public.crm_customers c
    where c.id = customer_id and c.owner_uid = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- Feature-flag key registration (enablement NOT set here)
-- ---------------------------------------------------------------------------
insert into public.app_feature_flags (key, enabled) values
  ('crm_enrichment', false),
  ('phase1_crm_enrichment', false)
on conflict (key) do nothing;

commit;
