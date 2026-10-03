-- CLIVORA v2.2.1 — fix Google auth profile lock (run after 003)
-- Problem: handle_new_user locked account_type as freelancer before app could set client role.

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
    false
  )
  on conflict (id) do update set
    email = excluded.email,
    name = coalesce(nullif(excluded.name, ''), public.profiles.name),
    updated_at = now();
  return new;
end;
$$;

create or replace function public.lock_profile_account_type()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.account_type is null or new.account_type = '' then
      new.account_type := 'freelancer';
    end if;
    if new.account_type_locked is null then
      new.account_type_locked := false;
    end if;
    return new;
  end if;

  if old.account_type_locked
     and new.account_type is distinct from old.account_type
     and not public.is_admin() then
    raise exception 'Account type is locked. One email cannot be both freelancer and client.';
  end if;

  if old.account_type_locked
     and new.role is distinct from old.role
     and not public.is_admin() then
    raise exception 'Only an admin can change user roles.';
  end if;

  return new;
end;
$$;

-- App finalizes role on first sign-in (Google or email)
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

grant execute on function public.finalize_account_type(text, text) to authenticated;
