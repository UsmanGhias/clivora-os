-- Phase 2: Connect trust layer + timesheets + support tickets + meetings
-- CLIVORA 2.12

-- ─── Reviews ─────────────────────────────────────────────────────────────────
create table if not exists public.connect_reviews (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references auth.users(id) on delete cascade,
  to_user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid references public.connect_requests(id) on delete set null,
  rating integer not null check (rating >= 1 and rating <= 5),
  body text not null default '',
  created_at timestamptz not null default now(),
  unique (from_user_id, to_user_id, request_id)
);

create index if not exists connect_reviews_to_idx on public.connect_reviews (to_user_id);

alter table public.connect_reviews enable row level security;
drop policy if exists connect_reviews_select on public.connect_reviews;
create policy connect_reviews_select on public.connect_reviews
  for select to authenticated using (true);
drop policy if exists connect_reviews_insert on public.connect_reviews;
create policy connect_reviews_insert on public.connect_reviews
  for insert to authenticated
  with check (from_user_id = auth.uid());

-- ─── Proposals ───────────────────────────────────────────────────────────────
create table if not exists public.connect_proposals (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references auth.users(id) on delete cascade,
  to_user_id uuid not null references auth.users(id) on delete cascade,
  need_id uuid references public.connect_need_posts(id) on delete set null,
  request_id uuid references public.connect_requests(id) on delete set null,
  amount numeric not null default 0,
  currency text not null default 'USD',
  timeline_days integer,
  message text not null default '',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.connect_proposals enable row level security;
drop policy if exists connect_proposals_parties on public.connect_proposals;
create policy connect_proposals_parties on public.connect_proposals
  for all to authenticated
  using (from_user_id = auth.uid() or to_user_id = auth.uid())
  with check (from_user_id = auth.uid());

-- ─── Milestones (escrow status machine; fund/release in Phase 3) ──────────────
create table if not exists public.connect_milestones (
  id uuid primary key default gen_random_uuid(),
  engagement_request_id uuid not null references public.connect_requests(id) on delete cascade,
  client_user_id uuid not null references auth.users(id) on delete cascade,
  freelancer_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  amount numeric not null default 0,
  currency text not null default 'USD',
  status text not null default 'pending',
  funded_at timestamptz,
  released_at timestamptz,
  disputed_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint connect_milestones_status_chk check (
    status in ('pending', 'funded', 'released', 'disputed', 'cancelled')
  )
);

alter table public.connect_milestones enable row level security;
drop policy if exists connect_milestones_parties on public.connect_milestones;
create policy connect_milestones_parties on public.connect_milestones
  for all to authenticated
  using (client_user_id = auth.uid() or freelancer_user_id = auth.uid())
  with check (client_user_id = auth.uid() or freelancer_user_id = auth.uid());

-- ─── Project time entries (cloud) + approval ─────────────────────────────────
create table if not exists public.crm_time_entries (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.crm_projects(id) on delete set null,
  local_id integer,
  description text not null default '',
  minutes integer not null default 0,
  billable boolean not null default true,
  hourly_rate numeric not null default 0,
  approval_status text not null default 'pending',
  work_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint crm_time_approval_chk check (
    approval_status in ('pending', 'approved', 'rejected')
  )
);

alter table public.crm_time_entries enable row level security;
drop policy if exists crm_time_entries_owner on public.crm_time_entries;
create policy crm_time_entries_owner on public.crm_time_entries
  for all to authenticated
  using (owner_uid = auth.uid())
  with check (owner_uid = auth.uid());

-- ─── Contract e-sign audit ───────────────────────────────────────────────────
create table if not exists public.contract_signatures (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  contract_local_id integer,
  signer_uid uuid references auth.users(id) on delete set null,
  signer_email text not null default '',
  signer_name text not null default '',
  signed_at timestamptz not null default now(),
  ip_address text,
  content_hash text not null default '',
  created_at timestamptz not null default now()
);

alter table public.contract_signatures enable row level security;
drop policy if exists contract_signatures_owner on public.contract_signatures;
create policy contract_signatures_owner on public.contract_signatures
  for all to authenticated
  using (owner_uid = auth.uid() or signer_uid = auth.uid())
  with check (owner_uid = auth.uid() or signer_uid = auth.uid());

-- ─── Meeting links (Jitsi pattern) ───────────────────────────────────────────
create table if not exists public.meeting_links (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.crm_projects(id) on delete set null,
  request_id uuid references public.connect_requests(id) on delete set null,
  title text not null default 'CLIVORA Meeting',
  room_url text not null,
  scheduled_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.meeting_links enable row level security;
drop policy if exists meeting_links_owner on public.meeting_links;
create policy meeting_links_owner on public.meeting_links
  for all to authenticated
  using (owner_uid = auth.uid())
  with check (owner_uid = auth.uid());

-- ─── Support tickets (helpdesk lite) ─────────────────────────────────────────
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null default '',
  body text not null default '',
  status text not null default 'open',
  priority text not null default 'normal',
  admin_notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.support_tickets enable row level security;
drop policy if exists support_tickets_owner on public.support_tickets;
create policy support_tickets_owner on public.support_tickets
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ─── Automation webhook outbox ───────────────────────────────────────────────
create table if not exists public.automation_webhook_queue (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.automation_webhook_queue enable row level security;
-- service role / admin only via service key; no client policies
