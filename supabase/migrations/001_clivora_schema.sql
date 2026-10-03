-- CLIVORA cross-device sync schema (run in Supabase SQL Editor)
-- Project: CLIVORA

-- Profiles mirror app users (keyed by Supabase Auth user id)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  name text not null default '',
  account_type text not null default 'freelancer',
  role text not null default 'user',
  firebase_uid text,
  updated_at timestamptz not null default now(),
  constraint profiles_email_unique unique (email)
);

-- Freelancer → client messages
create table if not exists public.client_messages (
  id uuid primary key default gen_random_uuid(),
  from_uid uuid not null references public.profiles (id) on delete cascade,
  to_uid uuid references public.profiles (id) on delete set null,
  from_email text not null,
  to_email text not null,
  subject text not null default '',
  body text not null,
  is_read boolean not null default false,
  project_share_id text,
  created_at timestamptz not null default now()
);

create index if not exists client_messages_to_email_idx on public.client_messages (to_email);
create index if not exists client_messages_to_uid_idx on public.client_messages (to_uid);
create index if not exists client_messages_created_at_idx on public.client_messages (created_at desc);

-- Shared project snapshots for client portal
create table if not exists public.project_shares (
  share_id text primary key,
  freelancer_uid uuid not null references public.profiles (id) on delete cascade,
  freelancer_email text not null,
  client_email text not null,
  client_uid uuid references public.profiles (id) on delete set null,
  local_project_id integer not null,
  project_name text not null,
  description text not null default '',
  status text not null default 'not_started',
  budget numeric not null default 0,
  currency text not null default 'USD',
  priority text not null default 'medium',
  deadline timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists project_shares_client_email_idx on public.project_shares (client_email);
create index if not exists project_shares_client_uid_idx on public.project_shares (client_uid);

-- Admin analytics mirror (optional)
create table if not exists public.clivora_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  user_email text not null default '',
  user_name text not null default '',
  plan text not null default 'free',
  amount numeric not null default 0,
  payload jsonb not null default '{}'::jsonb,
  source text not null default 'android',
  created_at timestamptz not null default now()
);

-- Auto-create profile row when a Supabase Auth user is created
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, name)
  values (
    new.id,
    lower(coalesce(new.email, '')),
    coalesce(new.raw_user_meta_data ->> 'name', '')
  )
  on conflict (id) do update set
    email = excluded.email,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Row Level Security
alter table public.profiles enable row level security;
alter table public.client_messages enable row level security;
alter table public.project_shares enable row level security;
alter table public.clivora_events enable row level security;

-- Profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);

drop policy if exists profiles_upsert on public.profiles;
create policy profiles_upsert on public.profiles
  for all to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Messages
drop policy if exists messages_select on public.client_messages;
create policy messages_select on public.client_messages
  for select to authenticated using (
    from_uid = auth.uid()
    or to_uid = auth.uid()
    or to_email = (select email from public.profiles where id = auth.uid())
  );

drop policy if exists messages_insert on public.client_messages;
create policy messages_insert on public.client_messages
  for insert to authenticated with check (from_uid = auth.uid());

drop policy if exists messages_update on public.client_messages;
create policy messages_update on public.client_messages
  for update to authenticated using (
    to_uid = auth.uid()
    or to_email = (select email from public.profiles where id = auth.uid())
  );

-- Project shares
drop policy if exists shares_select on public.project_shares;
create policy shares_select on public.project_shares
  for select to authenticated using (
    freelancer_uid = auth.uid()
    or client_uid = auth.uid()
    or client_email = (select email from public.profiles where id = auth.uid())
  );

drop policy if exists shares_write on public.project_shares;
create policy shares_write on public.project_shares
  for all to authenticated using (freelancer_uid = auth.uid())
  with check (freelancer_uid = auth.uid());

drop policy if exists shares_client_link on public.project_shares;
create policy shares_client_link on public.project_shares
  for update to authenticated using (
    client_email = (select email from public.profiles where id = auth.uid())
  );

-- Analytics
drop policy if exists events_insert on public.clivora_events;
create policy events_insert on public.clivora_events
  for insert to authenticated with check (true);

-- Realtime (cross-device live updates)
alter publication supabase_realtime add table public.client_messages;
alter publication supabase_realtime add table public.project_shares;
