-- Phase 3: escrow ledger, embeddings, vault shares, MFA helpers notes
-- CLIVORA 2.13

-- ─── Escrow ledger for Connect milestones ────────────────────────────────────
create table if not exists public.connect_escrow_ledger (
  id uuid primary key default gen_random_uuid(),
  milestone_id uuid not null references public.connect_milestones(id) on delete cascade,
  actor_uid uuid references auth.users(id) on delete set null,
  action text not null,
  amount numeric not null default 0,
  currency text not null default 'USD',
  stripe_payment_intent text,
  notes text not null default '',
  created_at timestamptz not null default now(),
  constraint connect_escrow_action_chk check (
    action in ('fund', 'release', 'refund', 'dispute_hold', 'admin_release')
  )
);

alter table public.connect_escrow_ledger enable row level security;
drop policy if exists connect_escrow_select on public.connect_escrow_ledger;
create policy connect_escrow_select on public.connect_escrow_ledger
  for select to authenticated
  using (
    exists (
      select 1 from public.connect_milestones m
      where m.id = milestone_id
        and (m.client_user_id = auth.uid() or m.freelancer_user_id = auth.uid())
    )
  );

-- ─── pgvector embeddings for CRM RAG ─────────────────────────────────────────
create extension if not exists vector;

create table if not exists public.crm_embeddings (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  content text not null default '',
  embedding vector(1536),
  updated_at timestamptz not null default now(),
  unique (owner_uid, entity_type, entity_id)
);

create index if not exists crm_embeddings_owner_idx on public.crm_embeddings (owner_uid);

alter table public.crm_embeddings enable row level security;
drop policy if exists crm_embeddings_owner on public.crm_embeddings;
create policy crm_embeddings_owner on public.crm_embeddings
  for all to authenticated
  using (owner_uid = auth.uid())
  with check (owner_uid = auth.uid());

-- ─── File vault signed share links ───────────────────────────────────────────
create table if not exists public.vault_share_links (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  file_name text not null default '',
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  expires_at timestamptz not null,
  max_downloads integer,
  download_count integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.vault_share_links enable row level security;
drop policy if exists vault_share_owner on public.vault_share_links;
create policy vault_share_owner on public.vault_share_links
  for all to authenticated
  using (owner_uid = auth.uid())
  with check (owner_uid = auth.uid());

-- ─── Stripe subscription mapping ─────────────────────────────────────────────
create table if not exists public.stripe_customers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  stripe_customer_id text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.stripe_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  stripe_subscription_id text not null unique,
  stripe_price_id text,
  plan text not null default 'pro',
  status text not null default 'active',
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.stripe_customers enable row level security;
alter table public.stripe_subscriptions enable row level security;
drop policy if exists stripe_customers_owner on public.stripe_customers;
create policy stripe_customers_owner on public.stripe_customers
  for select to authenticated using (user_id = auth.uid());
drop policy if exists stripe_subscriptions_owner on public.stripe_subscriptions;
create policy stripe_subscriptions_owner on public.stripe_subscriptions
  for select to authenticated using (user_id = auth.uid());
