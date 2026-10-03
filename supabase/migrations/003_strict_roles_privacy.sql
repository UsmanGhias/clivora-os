-- CLIVORA v2.2 — strict roles, privacy RLS, admin super-access
-- Run in Supabase SQL Editor after 002_notifications_client_tasks.sql
-- Optional clean slate (uncomment only if you want to wipe cloud sync data):
-- truncate public.client_tasks, public.notifications, public.client_messages, public.project_shares, public.clivora_events cascade;

-- Lock account type: one email = one role (freelancer OR client OR admin)
alter table public.profiles
  add column if not exists account_type_locked boolean not null default false;

alter table public.profiles
  drop constraint if exists profiles_account_type_check;

alter table public.profiles
  add constraint profiles_account_type_check
  check (account_type in ('freelancer', 'client', 'admin', 'user'));

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and (p.role = 'admin' or p.account_type = 'admin')
  );
$$;

create or replace function public.my_email()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select lower(coalesce(email, '')) from public.profiles where id = auth.uid();
$$;

-- Prevent account_type changes after lock
create or replace function public.lock_profile_account_type()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.account_type is null or new.account_type = '' then
      new.account_type := 'freelancer';
    end if;
    new.account_type_locked := true;
    return new;
  end if;

  if old.account_type_locked and new.account_type is distinct from old.account_type then
    raise exception 'Account type is locked. One email cannot be both freelancer and client.';
  end if;

  if old.account_type_locked and new.role is distinct from old.role
     and not public.is_admin() then
    raise exception 'Only an admin can change user roles.';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_lock_account_type on public.profiles;
create trigger profiles_lock_account_type
  before insert or update on public.profiles
  for each row execute function public.lock_profile_account_type();

-- Sign-up metadata → profile account_type
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text;
begin
  v_type := lower(coalesce(new.raw_user_meta_data ->> 'account_type', 'freelancer'));
  if v_type not in ('freelancer', 'client', 'admin') then
    v_type := 'freelancer';
  end if;

  insert into public.profiles (id, email, name, account_type, role, account_type_locked)
  values (
    new.id,
    lower(coalesce(new.email, '')),
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    v_type,
    case when v_type = 'admin' then 'admin' else 'user' end,
    true
  )
  on conflict (id) do update set
    email = excluded.email,
    name = coalesce(nullif(excluded.name, ''), public.profiles.name),
    updated_at = now();
  return new;
end;
$$;

-- ——— Profiles: own row + linked parties + admin ———
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (
    id = auth.uid()
    or public.is_admin()
    or id in (
      select freelancer_uid from public.project_shares ps
      where ps.client_uid = auth.uid() or ps.client_email = public.my_email()
    )
    or id in (
      select client_uid from public.project_shares ps
      where ps.freelancer_uid = auth.uid() and ps.client_uid is not null
    )
    or email in (
      select ps.client_email from public.project_shares ps
      where ps.freelancer_uid = auth.uid()
    )
  );

drop policy if exists profiles_upsert on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = auth.uid() or public.is_admin());

-- ——— Messages: only participants ———
drop policy if exists messages_select on public.client_messages;
create policy messages_select on public.client_messages
  for select to authenticated using (
    public.is_admin()
    or from_uid = auth.uid()
    or to_uid = auth.uid()
    or to_email = public.my_email()
  );

drop policy if exists messages_insert on public.client_messages;
create policy messages_insert on public.client_messages
  for insert to authenticated with check (
    from_uid = auth.uid()
    and (
      public.is_admin()
      or to_uid is not null
      or to_email <> ''
    )
  );

drop policy if exists messages_update on public.client_messages;
create policy messages_update on public.client_messages
  for update to authenticated using (
    public.is_admin()
    or to_uid = auth.uid()
    or to_email = public.my_email()
  );

-- ——— Project shares: freelancer + linked client only ———
drop policy if exists shares_select on public.project_shares;
create policy shares_select on public.project_shares
  for select to authenticated using (
    public.is_admin()
    or freelancer_uid = auth.uid()
    or client_uid = auth.uid()
    or client_email = public.my_email()
  );

drop policy if exists shares_write on public.project_shares;
create policy shares_write on public.project_shares
  for all to authenticated using (
    public.is_admin() or freelancer_uid = auth.uid()
  ) with check (
    public.is_admin() or freelancer_uid = auth.uid()
  );

drop policy if exists shares_client_link on public.project_shares;
create policy shares_client_link on public.project_shares
  for update to authenticated using (
    public.is_admin()
    or client_email = public.my_email()
  );

-- ——— Notifications ———
drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
  for select to authenticated using (
    public.is_admin()
    or user_uid = auth.uid()
    or from_uid = auth.uid()
  );

drop policy if exists notifications_insert on public.notifications;
create policy notifications_insert on public.notifications
  for insert to authenticated with check (
    from_uid = auth.uid()
    and (
      public.is_admin()
      or user_uid <> auth.uid()
    )
  );

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications
  for update to authenticated using (
    public.is_admin() or user_uid = auth.uid()
  );

drop policy if exists notifications_delete on public.notifications;
create policy notifications_delete on public.notifications
  for delete to authenticated using (
    public.is_admin() or user_uid = auth.uid()
  );

-- ——— Client tasks ———
drop policy if exists client_tasks_select on public.client_tasks;
create policy client_tasks_select on public.client_tasks
  for select to authenticated using (
    public.is_admin()
    or client_uid = auth.uid()
    or freelancer_uid = auth.uid()
  );

drop policy if exists client_tasks_insert on public.client_tasks;
create policy client_tasks_insert on public.client_tasks
  for insert to authenticated with check (
    public.is_admin() or client_uid = auth.uid()
  );

drop policy if exists client_tasks_update on public.client_tasks;
create policy client_tasks_update on public.client_tasks
  for update to authenticated using (
    public.is_admin()
    or freelancer_uid = auth.uid()
    or client_uid = auth.uid()
  );

drop policy if exists client_tasks_delete on public.client_tasks;
create policy client_tasks_delete on public.client_tasks
  for delete to authenticated using (
    public.is_admin()
    or client_uid = auth.uid()
    or freelancer_uid = auth.uid()
  );

-- ——— Analytics: admin read, authenticated insert ———
drop policy if exists events_insert on public.clivora_events;
create policy events_insert on public.clivora_events
  for insert to authenticated with check (true);

drop policy if exists events_select on public.clivora_events;
create policy events_select on public.clivora_events
  for select to authenticated using (public.is_admin());

-- Lookup UID for linked client (freelancer → client invite flow)
create or replace function public.uid_for_linked_email(p_email text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.profiles p
  where lower(p.email) = lower(trim(p_email))
    and (
      public.is_admin()
      or exists (
        select 1 from public.project_shares ps
        where ps.freelancer_uid = auth.uid()
          and lower(ps.client_email) = lower(trim(p_email))
      )
      or exists (
        select 1 from public.client_messages m
        where m.from_uid = auth.uid()
          and lower(m.to_email) = lower(trim(p_email))
      )
    )
  limit 1;
$$;

grant execute on function public.uid_for_linked_email(text) to authenticated;
grant execute on function public.is_admin() to authenticated;
