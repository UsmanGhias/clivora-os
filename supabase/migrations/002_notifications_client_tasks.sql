-- CLIVORA v2.1 — notifications + client-assigned tasks
-- Run in Supabase SQL Editor after 001_clivora_schema.sql

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_uid uuid not null references public.profiles (id) on delete cascade,
  from_uid uuid references public.profiles (id) on delete set null,
  title text not null,
  body text not null,
  kind text not null default 'info',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_uid_idx on public.notifications (user_uid);
create index if not exists notifications_created_at_idx on public.notifications (created_at desc);

create table if not exists public.client_tasks (
  id uuid primary key default gen_random_uuid(),
  client_uid uuid not null references public.profiles (id) on delete cascade,
  freelancer_uid uuid not null references public.profiles (id) on delete cascade,
  project_share_id text,
  title text not null,
  description text not null default '',
  status text not null default 'pending',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists client_tasks_freelancer_idx on public.client_tasks (freelancer_uid);
create index if not exists client_tasks_client_idx on public.client_tasks (client_uid);

alter table public.notifications enable row level security;
alter table public.client_tasks enable row level security;

drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
  for select to authenticated using (user_uid = auth.uid() or from_uid = auth.uid());

drop policy if exists notifications_insert on public.notifications;
create policy notifications_insert on public.notifications
  for insert to authenticated with check (from_uid = auth.uid() or user_uid = auth.uid());

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications
  for update to authenticated using (user_uid = auth.uid());

drop policy if exists notifications_delete on public.notifications;
create policy notifications_delete on public.notifications
  for delete to authenticated using (user_uid = auth.uid());

drop policy if exists client_tasks_select on public.client_tasks;
create policy client_tasks_select on public.client_tasks
  for select to authenticated using (client_uid = auth.uid() or freelancer_uid = auth.uid());

drop policy if exists client_tasks_insert on public.client_tasks;
create policy client_tasks_insert on public.client_tasks
  for insert to authenticated with check (client_uid = auth.uid());

drop policy if exists client_tasks_update on public.client_tasks;
create policy client_tasks_update on public.client_tasks
  for update to authenticated using (freelancer_uid = auth.uid() or client_uid = auth.uid());

drop policy if exists client_tasks_delete on public.client_tasks;
create policy client_tasks_delete on public.client_tasks
  for delete to authenticated using (client_uid = auth.uid() or freelancer_uid = auth.uid());

alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.client_tasks;
