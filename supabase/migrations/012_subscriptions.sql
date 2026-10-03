-- CLIVORA — server-verified Google Play subscriptions

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null,
  purchase_token text not null,
  package_name text not null default 'org.codcrafters.clivora',
  expires_at timestamptz,
  verified_at timestamptz not null default now(),
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (purchase_token)
);

create index if not exists subscriptions_user_id_idx on public.subscriptions (user_id);
create index if not exists subscriptions_status_idx on public.subscriptions (status);

alter table public.subscriptions enable row level security;

drop policy if exists subscriptions_select_own on public.subscriptions;
create policy subscriptions_select_own on public.subscriptions
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists subscriptions_service_write on public.subscriptions;
create policy subscriptions_service_write on public.subscriptions
  for all to service_role
  using (true) with check (true);

alter table public.profiles
  add column if not exists subscription_plan text not null default 'free';
