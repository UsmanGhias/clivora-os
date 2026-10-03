-- CLIVORA cloud CRM tables (applied via Supabase MCP 2026-07-10)
-- Source of truth for web + Flutter sync; local SQLite remains offline cache.

create table if not exists public.crm_customers (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  local_id integer,
  contact_person text not null default '',
  company text not null default '',
  emails jsonb not null default '[]'::jsonb,
  phones jsonb not null default '[]'::jsonb,
  whatsapp text not null default '',
  address text not null default '',
  city text not null default '',
  postal_code text not null default '',
  country text not null default '',
  notes text not null default '',
  tags jsonb not null default '[]'::jsonb,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists crm_customers_owner_local_uidx
  on public.crm_customers (owner_uid, local_id) where local_id is not null;
create index if not exists crm_customers_owner_idx on public.crm_customers (owner_uid);

create table if not exists public.crm_projects (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  local_id integer,
  customer_id uuid references public.crm_customers(id) on delete set null,
  local_customer_id integer,
  name text not null default '',
  description text not null default '',
  budget numeric not null default 0,
  currency text not null default 'USD',
  pricing_type text not null default 'fixed',
  start_date timestamptz,
  deadline timestamptz,
  priority text not null default 'medium',
  status text not null default 'not_started',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists crm_projects_owner_local_uidx
  on public.crm_projects (owner_uid, local_id) where local_id is not null;

create table if not exists public.crm_invoices (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  local_id integer,
  customer_id uuid references public.crm_customers(id) on delete set null,
  project_id uuid references public.crm_projects(id) on delete set null,
  local_customer_id integer,
  local_project_id integer,
  invoice_number text not null default '',
  status text not null default 'draft',
  subtotal numeric not null default 0,
  tax_rate numeric not null default 0,
  discount numeric not null default 0,
  total numeric not null default 0,
  amount_paid numeric not null default 0,
  currency text not null default 'USD',
  line_items jsonb not null default '[]'::jsonb,
  issue_date timestamptz not null default now(),
  due_date timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists crm_invoices_owner_local_uidx
  on public.crm_invoices (owner_uid, local_id) where local_id is not null;

create table if not exists public.crm_expenses (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  local_id integer,
  title text not null default '',
  amount numeric not null default 0,
  currency text not null default 'USD',
  category text not null default 'other',
  notes text not null default '',
  expense_date timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.crm_notes (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  local_id integer,
  title text not null default '',
  body text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.crm_customers enable row level security;
alter table public.crm_projects enable row level security;
alter table public.crm_invoices enable row level security;
alter table public.crm_expenses enable row level security;
alter table public.crm_notes enable row level security;

-- Owner-only RLS (also applied via MCP migration crm_rls_policies)
drop policy if exists crm_customers_owner_all on public.crm_customers;
create policy crm_customers_owner_all on public.crm_customers
  for all to authenticated
  using (owner_uid = auth.uid())
  with check (owner_uid = auth.uid());

drop policy if exists crm_projects_owner_all on public.crm_projects;
create policy crm_projects_owner_all on public.crm_projects
  for all to authenticated
  using (owner_uid = auth.uid())
  with check (owner_uid = auth.uid());

drop policy if exists crm_invoices_owner_all on public.crm_invoices;
create policy crm_invoices_owner_all on public.crm_invoices
  for all to authenticated
  using (owner_uid = auth.uid())
  with check (owner_uid = auth.uid());

drop policy if exists crm_expenses_owner_all on public.crm_expenses;
create policy crm_expenses_owner_all on public.crm_expenses
  for all to authenticated
  using (owner_uid = auth.uid())
  with check (owner_uid = auth.uid());

drop policy if exists crm_notes_owner_all on public.crm_notes;
create policy crm_notes_owner_all on public.crm_notes
  for all to authenticated
  using (owner_uid = auth.uid())
  with check (owner_uid = auth.uid());
