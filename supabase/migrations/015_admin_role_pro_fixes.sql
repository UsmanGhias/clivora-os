-- CLIVORA v2.6.7 — preserve client account_type on admin grant, client Pro, schema fixes

-- Invoice shares: expires_at column (app sends this; missing column caused 400 errors)
alter table public.invoice_shares
  add column if not exists expires_at timestamptz;

update public.invoice_shares
set expires_at = updated_at + interval '90 days'
where expires_at is null;

create index if not exists invoice_shares_expires_at_idx
  on public.invoice_shares (expires_at);

-- Referral codes: upsert needs UPDATE policy (404/RLS failures on upsert)
drop policy if exists referral_codes_update_own on public.referral_codes;
create policy referral_codes_update_own on public.referral_codes
  for update to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

-- Grant admin: only elevate role — never overwrite freelancer/client account_type
create or replace function public.grant_admin_by_email(p_email text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target uuid;
  v_type text;
begin
  if not public.is_super_admin() then
    raise exception 'Only super admin can grant admin access.';
  end if;

  select id, account_type into v_target, v_type
  from public.profiles
  where lower(email) = lower(trim(p_email))
  limit 1;

  if v_target is null then
    raise exception 'No profile found for that email.';
  end if;

  update public.profiles
  set
    role = 'admin',
    account_type = case
      when account_type in ('client', 'freelancer') then account_type
      when account_type = 'admin' then coalesce(nullif(v_type, 'admin'), 'freelancer')
      else coalesce(nullif(account_type, ''), 'freelancer')
    end,
    account_type_locked = true,
    updated_at = now()
  where id = v_target;
end;
$$;

revoke all on function public.grant_admin_by_email(text) from public, anon;
grant execute on function public.grant_admin_by_email(text) to authenticated;

-- Grant or revoke Pro for any account type (freelancer or client)
create or replace function public.grant_pro_by_email(p_email text, p_plan text default 'pro')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target uuid;
  v_plan text := lower(trim(coalesce(p_plan, 'pro')));
begin
  if not public.is_super_admin() then
    raise exception 'Only super admin can change subscription plans.';
  end if;
  if v_plan not in ('pro', 'free') then
    raise exception 'Plan must be pro or free.';
  end if;

  select id into v_target
  from public.profiles
  where lower(email) = lower(trim(p_email))
  limit 1;

  if v_target is null then
    raise exception 'No profile found for that email.';
  end if;

  update public.profiles
  set subscription_plan = v_plan, updated_at = now()
  where id = v_target;

  if v_plan = 'pro' then
    delete from public.subscriptions where user_id = v_target and product_id = 'admin_grant_pro';
    insert into public.subscriptions (user_id, product_id, purchase_token, status, expires_at, verified_at)
    values (v_target, 'admin_grant_pro', 'admin_' || v_target::text, 'active', now() + interval '1 year', now());
  else
    update public.subscriptions
    set status = 'canceled', updated_at = now()
    where user_id = v_target and status = 'active';
  end if;
end;
$$;

revoke all on function public.grant_pro_by_email(text, text) from public, anon;
grant execute on function public.grant_pro_by_email(text, text) to authenticated;

-- Repair profiles before tightening trigger (account_type=admin was wrongly used as role)
alter table public.profiles disable trigger profiles_lock_account_type;

update public.profiles
set account_type = 'client', updated_at = now()
where account_type = 'admin'
  and exists (select 1 from public.project_shares ps where ps.client_uid = profiles.id);

update public.profiles
set account_type = 'freelancer', updated_at = now()
where account_type = 'admin'
  and not exists (select 1 from public.project_shares ps where ps.client_uid = profiles.id);

alter table public.profiles enable trigger profiles_lock_account_type;

-- Lock profile: admin is a role, not an account_type replacement
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
    if new.account_type = 'admin' then
      new.account_type := 'freelancer';
    end if;
    if new.role = 'admin' and not public.is_allowlisted_admin(new.email) then
      new.role := 'user';
    end if;
    return new;
  end if;

  if new.account_type = 'admin' and old.account_type in ('client', 'freelancer') then
    new.account_type := old.account_type;
  end if;

  if new.role = 'admin'
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
