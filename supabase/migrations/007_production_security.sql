-- CLIVORA v2.3.7 — production security hardening

-- Server-side admin allowlist (never trust client metadata for admin).
-- Empty by default. To make someone an admin, insert their email with the
-- service role: insert into public.admin_allowlist(email) values ('you@example.com');
create table if not exists public.admin_allowlist (
  email text primary key check (email = lower(trim(email))),
  is_super boolean not null default false,
  created_at timestamptz not null default now()
);
-- No policies: only the service role (dashboard / SQL editor) can read or change it.
alter table public.admin_allowlist enable row level security;

create or replace function public.is_allowlisted_admin(p_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_allowlist
    where email = lower(trim(coalesce(p_email, '')))
  );
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_allowlist
    where email = lower(public.my_email()) and is_super
  );
$$;

revoke all on function public.is_allowlisted_admin(text) from public, anon;
revoke all on function public.is_super_admin() from public, anon;
grant execute on function public.is_allowlisted_admin(text) to authenticated;
grant execute on function public.is_super_admin() to authenticated;

-- Block self-service admin in signup trigger
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text;
  v_email text;
begin
  v_email := lower(coalesce(new.email, ''));
  v_type := lower(coalesce(new.raw_user_meta_data ->> 'account_type', 'freelancer'));
  if v_type not in ('freelancer', 'client') then
    v_type := 'freelancer';
  end if;
  if public.is_allowlisted_admin(v_email) then
    v_type := 'admin';
  end if;

  insert into public.profiles (id, email, name, account_type, role, account_type_locked)
  values (
    new.id,
    v_email,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    v_type,
    case when v_type = 'admin' then 'admin' else 'user' end,
    false
  )
  on conflict (id) do update set
    email = excluded.email,
    name = coalesce(nullif(excluded.name, ''), public.profiles.name),
    updated_at = now();
  return new;
end;
$$;

-- Finalize account type — reject admin unless allowlisted
create or replace function public.finalize_account_type(p_account_type text, p_name text default '')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_type text := lower(trim(p_account_type));
  v_email text;
  v_locked boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if v_type not in ('freelancer', 'client', 'admin') then
    v_type := 'freelancer';
  end if;

  select lower(coalesce(email, '')) into v_email from auth.users where id = v_uid;
  if v_type = 'admin' and not public.is_allowlisted_admin(v_email) then
    v_type := 'freelancer';
  end if;

  select account_type_locked into v_locked from public.profiles where id = v_uid;

  if v_locked is true and not public.is_admin() then
    update public.profiles
    set name = coalesce(nullif(trim(p_name), ''), name), updated_at = now()
    where id = v_uid;
    return;
  end if;

  insert into public.profiles (id, email, name, account_type, role, account_type_locked)
  values (
    v_uid,
    v_email,
    coalesce(nullif(trim(p_name), ''), ''),
    v_type,
    case when v_type = 'admin' then 'admin' else 'user' end,
    true
  )
  on conflict (id) do update set
    account_type = excluded.account_type,
    role = excluded.role,
    name = coalesce(nullif(excluded.name, ''), public.profiles.name),
    account_type_locked = true,
    updated_at = now();
end;
$$;

-- Lock profile: block non-allowlisted admin promotion
create or replace function public.lock_profile_account_type()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.account_type is null or new.account_type = '' then
      new.account_type := 'freelancer';
    end if;
    if new.account_type_locked is null then
      new.account_type_locked := false;
    end if;
    if (new.account_type = 'admin' or new.role = 'admin')
       and not public.is_allowlisted_admin(new.email) then
      new.account_type := 'freelancer';
      new.role := 'user';
    end if;
    return new;
  end if;

  if (new.account_type = 'admin' or new.role = 'admin')
     and not public.is_allowlisted_admin(new.email)
     and not public.is_super_admin() then
    raise exception 'Admin role can only be assigned by super admin.';
  end if;

  if old.account_type_locked
     and new.account_type is distinct from old.account_type
     and not public.is_admin() then
    raise exception 'Account type is locked. One email cannot be both freelancer and client.';
  end if;

  if old.account_type_locked
     and new.role is distinct from old.role
     and not public.is_super_admin() then
    raise exception 'Only super admin can change user roles.';
  end if;

  return new;
end;
$$;

-- Super-admin-only grant admin RPC
create or replace function public.grant_admin_by_email(p_email text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target uuid;
begin
  if not public.is_super_admin() then
    raise exception 'Only super admin can grant admin access.';
  end if;

  select id into v_target from public.profiles where lower(email) = lower(trim(p_email)) limit 1;
  if v_target is null then
    raise exception 'No profile found for that email.';
  end if;

  update public.profiles
  set role = 'admin', account_type = 'admin', account_type_locked = true, updated_at = now()
  where id = v_target;
end;
$$;

revoke all on function public.grant_admin_by_email(text) from public, anon;
grant execute on function public.grant_admin_by_email(text) to authenticated;

-- Invoice shares: clients may only update payment fields
create or replace function public.restrict_invoice_share_client_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if public.is_admin() or auth.uid() = old.freelancer_uid then
    return new;
  end if;

  if new.freelancer_uid is distinct from old.freelancer_uid
     or new.freelancer_email is distinct from old.freelancer_email
     or new.client_email is distinct from old.client_email
     or new.local_invoice_id is distinct from old.local_invoice_id
     or new.local_project_id is distinct from old.local_project_id
     or new.invoice_number is distinct from old.invoice_number
     or new.total is distinct from old.total
     or new.currency is distinct from old.currency
     or new.due_date is distinct from old.due_date
     or new.share_id is distinct from old.share_id then
    raise exception 'Clients can only update payment status fields.';
  end if;

  return new;
end;
$$;

drop trigger if exists invoice_shares_client_field_guard on public.invoice_shares;
create trigger invoice_shares_client_field_guard
  before update on public.invoice_shares
  for each row execute function public.restrict_invoice_share_client_update();

-- Messages: recipients may only mark read
create or replace function public.restrict_message_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if public.is_admin() or auth.uid() = old.from_uid then
    return new;
  end if;

  if new.subject is distinct from old.subject
     or new.body is distinct from old.body
     or new.from_uid is distinct from old.from_uid
     or new.to_uid is distinct from old.to_uid
     or new.to_email is distinct from old.to_email
     or new.from_email is distinct from old.from_email
     or new.project_share_id is distinct from old.project_share_id then
    raise exception 'Recipients can only mark messages as read.';
  end if;

  return new;
end;
$$;

drop trigger if exists client_messages_update_guard on public.client_messages;
create trigger client_messages_update_guard
  before update on public.client_messages
  for each row execute function public.restrict_message_update();

-- Messages: require linked relationship on insert
create or replace function public.require_message_link()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if exists (
    select 1 from public.project_shares ps
    where (ps.freelancer_uid = new.from_uid and lower(ps.client_email) = lower(new.to_email))
       or (ps.client_uid = new.from_uid and lower(ps.freelancer_email) = lower(new.from_email))
  ) then
    return new;
  end if;

  if exists (
    select 1 from public.client_messages cm
    where (cm.from_uid = new.from_uid and lower(cm.to_email) = lower(new.to_email))
       or (cm.to_uid = new.from_uid and lower(cm.from_email) = lower(new.from_email))
       or (cm.from_uid = new.to_uid and lower(cm.to_email) = lower(new.from_email))
       or (lower(cm.to_email) = lower(new.from_email) and cm.from_uid = new.from_uid)
  ) then
    return new;
  end if;

  if exists (
    select 1 from public.invoice_shares inv
    where (inv.freelancer_uid = new.from_uid and lower(inv.client_email) = lower(new.to_email))
       or (inv.client_uid = new.from_uid and lower(inv.freelancer_email) = lower(new.from_email))
  ) then
    return new;
  end if;

  raise exception 'You can only message linked contacts on shared projects.';
end;
$$;

drop trigger if exists client_messages_link_guard on public.client_messages;
create trigger client_messages_link_guard
  before insert on public.client_messages
  for each row execute function public.require_message_link();

-- Email monthly quota (max 3000/month via edge function)
create table if not exists public.email_send_log (
  id bigserial primary key,
  sent_at timestamptz not null default now(),
  purpose text not null,
  recipient text not null,
  sender_uid uuid
);

create index if not exists email_send_log_month_idx on public.email_send_log (date_trunc('month', sent_at));

alter table public.email_send_log enable row level security;

drop policy if exists email_send_log_admin on public.email_send_log;
create policy email_send_log_admin on public.email_send_log
  for select to authenticated using (public.is_admin());

-- Chat image attachments bucket
insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', true)
on conflict (id) do update set public = true;

drop policy if exists chat_attachments_read on storage.objects;
create policy chat_attachments_read on storage.objects
  for select using (bucket_id = 'chat-attachments');

drop policy if exists chat_attachments_upload on storage.objects;
create policy chat_attachments_upload on storage.objects
  for insert to authenticated
  with check (bucket_id = 'chat-attachments' and (storage.foldername(name))[1] = auth.uid()::text);
