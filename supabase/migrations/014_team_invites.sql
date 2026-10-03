-- CLIVORA v2.6.6 — team invites with shared project access
-- Run in Supabase SQL Editor after prior migrations.

create table if not exists public.team_invites (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references public.profiles (id) on delete cascade,
  invitee_email text not null,
  invitee_name text not null default '',
  invitee_uid uuid references public.profiles (id) on delete set null,
  role text not null default 'member',
  project_share_id text,
  project_name text not null default '',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

create index if not exists team_invites_owner_idx on public.team_invites (owner_uid);
create index if not exists team_invites_invitee_email_idx on public.team_invites (lower(invitee_email));
create index if not exists team_invites_invitee_uid_idx on public.team_invites (invitee_uid);
create index if not exists team_invites_status_idx on public.team_invites (status);

alter table public.team_invites enable row level security;

drop policy if exists team_invites_select on public.team_invites;
create policy team_invites_select on public.team_invites
  for select to authenticated
  using (
    owner_uid = auth.uid()
    or invitee_uid = auth.uid()
    or lower(invitee_email) = lower(coalesce((select email from public.profiles where id = auth.uid()), ''))
  );

drop policy if exists team_invites_insert on public.team_invites;
create policy team_invites_insert on public.team_invites
  for insert to authenticated
  with check (owner_uid = auth.uid());

drop policy if exists team_invites_update on public.team_invites;
create policy team_invites_update on public.team_invites
  for update to authenticated
  using (
    owner_uid = auth.uid()
    or invitee_uid = auth.uid()
    or lower(invitee_email) = lower(coalesce((select email from public.profiles where id = auth.uid()), ''))
  );

drop policy if exists team_invites_delete on public.team_invites;
create policy team_invites_delete on public.team_invites
  for delete to authenticated
  using (owner_uid = auth.uid());

alter publication supabase_realtime add table public.team_invites;
