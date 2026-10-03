-- CLIVORA — cloud referral tracking

create table if not exists public.referral_codes (
  user_id uuid primary key references auth.users (id) on delete cascade,
  code text not null unique,
  referral_count integer not null default 0,
  bonus_days_earned integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.referral_redemptions (
  id uuid primary key default gen_random_uuid(),
  referrer_user_id uuid not null references auth.users (id) on delete cascade,
  referred_user_id uuid not null unique references auth.users (id) on delete cascade,
  referral_code text not null,
  redeemed_at timestamptz not null default now()
);

alter table public.referral_codes enable row level security;
alter table public.referral_redemptions enable row level security;

drop policy if exists referral_codes_select on public.referral_codes;
create policy referral_codes_select on public.referral_codes
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists referral_codes_upsert_own on public.referral_codes;
create policy referral_codes_upsert_own on public.referral_codes
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists referral_redemptions_select on public.referral_redemptions;
create policy referral_redemptions_select on public.referral_redemptions
  for select to authenticated
  using (referrer_user_id = auth.uid() or referred_user_id = auth.uid() or public.is_admin());

create or replace function public.credit_referral_on_purchase(
  p_referrer_uid uuid,
  p_referred_uid uuid,
  p_code text,
  p_bonus_days integer default 7
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_referrer_uid is null or p_referred_uid is null or p_referrer_uid = p_referred_uid then
    return;
  end if;
  if exists (select 1 from referral_redemptions where referred_user_id = p_referred_uid) then
    return;
  end if;
  insert into referral_redemptions (referrer_user_id, referred_user_id, referral_code)
  values (p_referrer_uid, p_referred_uid, upper(trim(p_code)));
  insert into referral_codes (user_id, code, referral_count, bonus_days_earned)
  values (p_referrer_uid, upper(trim(p_code)), 1, p_bonus_days)
  on conflict (user_id) do update set
    referral_count = referral_codes.referral_count + 1,
    bonus_days_earned = referral_codes.bonus_days_earned + p_bonus_days,
    updated_at = now();
end;
$$;

grant execute on function public.credit_referral_on_purchase(uuid, uuid, text, integer) to service_role;

revoke all on function public.credit_referral_on_purchase(uuid, uuid, text, integer) from public;
revoke all on function public.credit_referral_on_purchase(uuid, uuid, text, integer) from anon;
revoke all on function public.credit_referral_on_purchase(uuid, uuid, text, integer) from authenticated;
