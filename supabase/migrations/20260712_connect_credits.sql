-- CLIVORA Connect Credits: monthly anti-spam allowance with transactional debits.
-- No money movement or paid credit packs are introduced by this migration.

create table if not exists public.connect_credit_legacy_cohort (
  user_id uuid primary key references auth.users(id) on delete cascade,
  grandfather_until timestamptz not null,
  created_at timestamptz not null default now()
);

insert into public.connect_credit_legacy_cohort (user_id, grandfather_until)
select p.id, timestamptz '2026-10-10 00:00:00+00'
from public.profiles p
where p.subscription_plan = 'pro_plus'
on conflict (user_id) do nothing;

create table if not exists public.connect_credit_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'free',
  allowance integer not null default 5 check (allowance >= 0),
  balance integer not null default 5 check (balance >= 0),
  current_period_start timestamptz not null,
  current_period_end timestamptz not null,
  legacy_unlimited boolean not null default false,
  grandfather_until timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.connect_credit_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_type text not null check (entry_type in ('grant', 'debit', 'refund', 'expire', 'upgrade')),
  action text not null,
  amount integer not null check (amount >= 0),
  related_type text,
  related_id uuid,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

create index if not exists connect_credit_ledger_user_created_idx
  on public.connect_credit_ledger (user_id, created_at desc);

alter table public.connect_credit_legacy_cohort enable row level security;
alter table public.connect_credit_accounts enable row level security;
alter table public.connect_credit_ledger enable row level security;

drop policy if exists connect_credit_cohort_owner on public.connect_credit_legacy_cohort;
create policy connect_credit_cohort_owner on public.connect_credit_legacy_cohort
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
drop policy if exists connect_credit_accounts_owner on public.connect_credit_accounts;
create policy connect_credit_accounts_owner on public.connect_credit_accounts
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
drop policy if exists connect_credit_ledger_owner on public.connect_credit_ledger;
create policy connect_credit_ledger_owner on public.connect_credit_ledger
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

revoke all on public.connect_credit_accounts from anon, authenticated;
revoke all on public.connect_credit_ledger from anon, authenticated;
grant select on public.connect_credit_accounts to authenticated;
grant select on public.connect_credit_ledger to authenticated;

create or replace function public.connect_credit_allowance(p_plan text)
returns integer
language sql immutable
set search_path = public
as $$
  select case lower(coalesce(p_plan, 'free'))
    when 'pro_plus' then 100
    when 'plus' then 100
    when 'proplus' then 100
    when 'pro' then 30
    else 5
  end;
$$;

create or replace function public.connect_credit_eligible(p_uid uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile record;
  v_confirmed timestamptz;
begin
  if p_uid is null or p_uid <> auth.uid() then return false; end if;
  select role, account_type, name, is_blocked, is_restricted
    into v_profile from public.profiles where id = p_uid;
  select email_confirmed_at into v_confirmed from auth.users where id = p_uid;
  if v_confirmed is null or v_profile is null
     or v_profile.is_blocked = true or v_profile.is_restricted = true
     or coalesce(v_profile.role, '') not in ('user', 'admin') then
    return false;
  end if;
  if v_profile.account_type = 'freelancer' then
    return exists (
      select 1 from public.connect_profiles cp
      where cp.user_id = p_uid and coalesce(cp.profile_completeness, 0) >= 60
    );
  end if;
  return coalesce(nullif(trim(v_profile.name), ''), '') <> ''
    and v_profile.account_type in ('client', 'admin');
end;
$$;

create or replace function public.connect_prepare_credit_account(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan text;
  v_allowance integer;
  v_start timestamptz := date_trunc('month', timezone('utc', now())) at time zone 'utc';
  v_end timestamptz := (date_trunc('month', timezone('utc', now())) + interval '1 month') at time zone 'utc';
  v_account public.connect_credit_accounts;
  v_legacy_until timestamptz;
begin
  if p_uid <> auth.uid() and not public.is_admin() then raise exception 'ACTION_NOT_ALLOWED'; end if;
  select coalesce(subscription_plan, 'free') into v_plan from public.profiles where id = p_uid;
  v_allowance := public.connect_credit_allowance(v_plan);
  select grandfather_until into v_legacy_until
    from public.connect_credit_legacy_cohort where user_id = p_uid;

  select * into v_account from public.connect_credit_accounts where user_id = p_uid for update;
  if not found then
    insert into public.connect_credit_accounts
      (user_id, plan, allowance, balance, current_period_start, current_period_end,
       legacy_unlimited, grandfather_until)
    values
      (p_uid, v_plan, v_allowance, v_allowance, v_start, v_end,
       v_legacy_until is not null and v_legacy_until > now(), v_legacy_until);
    if v_legacy_until is not null and v_legacy_until > now() then
      update public.connect_credit_accounts set balance = 0 where user_id = p_uid;
    else
      insert into public.connect_credit_ledger(user_id, entry_type, action, amount, idempotency_key)
      values (p_uid, 'grant', 'monthly_grant', v_allowance,
        'grant:' || to_char(v_start at time zone 'utc', 'YYYY-MM'));
    end if;
    return;
  end if;

  if v_account.legacy_unlimited and coalesce(v_account.grandfather_until, now()) > now() then
    return;
  end if;
  if v_account.legacy_unlimited then
    update public.connect_credit_accounts
      set legacy_unlimited = false, plan = v_plan, allowance = v_allowance,
          balance = v_allowance, current_period_start = v_start, current_period_end = v_end,
          updated_at = now()
      where user_id = p_uid;
    insert into public.connect_credit_ledger(user_id, entry_type, action, amount, idempotency_key)
      values (p_uid, 'grant', 'grandfather_conversion', v_allowance,
        'grandfather_conversion:' || to_char(v_start at time zone 'utc', 'YYYY-MM'))
      on conflict do nothing;
    return;
  end if;
  if v_account.current_period_start < v_start then
    insert into public.connect_credit_ledger(user_id, entry_type, action, amount, idempotency_key)
      values (p_uid, 'expire', 'monthly_expiry', v_account.balance,
        'expire:' || to_char(v_account.current_period_start at time zone 'utc', 'YYYY-MM'))
      on conflict do nothing;
    update public.connect_credit_accounts
      set plan = v_plan, allowance = v_allowance, balance = v_allowance,
          current_period_start = v_start, current_period_end = v_end, updated_at = now()
      where user_id = p_uid;
    insert into public.connect_credit_ledger(user_id, entry_type, action, amount, idempotency_key)
      values (p_uid, 'grant', 'monthly_grant', v_allowance,
        'grant:' || to_char(v_start at time zone 'utc', 'YYYY-MM'))
      on conflict do nothing;
  elsif v_allowance > v_account.allowance then
    update public.connect_credit_accounts
      set plan = v_plan, allowance = v_allowance,
          balance = balance + (v_allowance - allowance), updated_at = now()
      where user_id = p_uid;
    insert into public.connect_credit_ledger(user_id, entry_type, action, amount, idempotency_key)
      values (p_uid, 'upgrade', 'plan_upgrade', v_allowance - v_account.allowance,
        'upgrade:' || to_char(v_start at time zone 'utc', 'YYYY-MM') || ':' || v_allowance)
      on conflict do nothing;
  else
    update public.connect_credit_accounts set plan = v_plan, updated_at = now() where user_id = p_uid;
  end if;
end;
$$;

create or replace function public.connect_credit_summary()
returns table (plan text, allowance integer, balance integer, period_start timestamptz,
  period_end timestamptz, legacy_unlimited boolean, grandfather_until timestamptz)
language plpgsql security definer set search_path = public
as $$
begin
  if not public.connect_credit_eligible(auth.uid()) then raise exception 'PROFILE_INCOMPLETE'; end if;
  perform public.connect_prepare_credit_account(auth.uid());
  return query select a.plan, a.allowance, a.balance, a.current_period_start,
    a.current_period_end, a.legacy_unlimited, a.grandfather_until
    from public.connect_credit_accounts a where a.user_id = auth.uid();
end;
$$;

create or replace function public.connect_spend_credits(
  p_action text, p_related_type text default null, p_related_id uuid default null,
  p_idempotency_key text default null)
returns integer
language plpgsql security definer set search_path = public
as $$
declare
  v_cost integer := case p_action
    when 'proposal' then 1 when 'contact' then 1
    when 'publish_need' then 3 when 'publish_profile' then 3 else 0 end;
  v_account public.connect_credit_accounts;
  v_key text := coalesce(nullif(p_idempotency_key, ''), gen_random_uuid()::text);
begin
  if v_cost = 0 then raise exception 'ACTION_NOT_ALLOWED'; end if;
  if not public.connect_credit_eligible(auth.uid()) then raise exception 'PROFILE_INCOMPLETE'; end if;
  perform public.connect_prepare_credit_account(auth.uid());
  if exists (select 1 from public.connect_credit_ledger where user_id = auth.uid() and idempotency_key = v_key) then
    return v_cost;
  end if;
  select * into v_account from public.connect_credit_accounts where user_id = auth.uid() for update;
  if not v_account.legacy_unlimited and v_account.balance < v_cost then raise exception 'INSUFFICIENT_CREDITS'; end if;
  insert into public.connect_credit_ledger(user_id, entry_type, action, amount, related_type, related_id, idempotency_key)
    values (auth.uid(), 'debit', p_action, case when v_account.legacy_unlimited then 0 else v_cost end,
      p_related_type, p_related_id, v_key);
  if not v_account.legacy_unlimited then
    update public.connect_credit_accounts set balance = balance - v_cost, updated_at = now()
      where user_id = auth.uid();
  end if;
  return v_cost;
end;
$$;

create or replace function public.connect_refund_moderated_action(p_ledger_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = public
as $$
declare v_entry public.connect_credit_ledger;
begin
  if not public.is_admin() then raise exception 'ACTION_NOT_ALLOWED'; end if;
  select * into v_entry from public.connect_credit_ledger where id = p_ledger_id for update;
  if not found or v_entry.entry_type <> 'debit' or v_entry.amount = 0 then raise exception 'ACTION_NOT_ALLOWED'; end if;
  if exists (select 1 from public.connect_credit_ledger where user_id = v_entry.user_id and idempotency_key = 'refund:' || p_ledger_id::text) then return; end if;
  insert into public.connect_credit_ledger(user_id, entry_type, action, amount, related_type, related_id, idempotency_key)
    values (v_entry.user_id, 'refund', left(coalesce(p_reason, 'moderation_refund'), 80), v_entry.amount,
      v_entry.related_type, v_entry.related_id, 'refund:' || p_ledger_id::text);
  update public.connect_credit_accounts set balance = least(balance + v_entry.amount, allowance), updated_at = now()
    where user_id = v_entry.user_id;
end;
$$;

grant execute on function public.connect_credit_allowance(text) to authenticated;
grant execute on function public.connect_credit_summary() to authenticated;
grant execute on function public.connect_spend_credits(text, text, uuid, text) to authenticated;
grant execute on function public.connect_refund_moderated_action(uuid, text) to authenticated;

-- Domain wrappers keep credit debit and marketplace mutation in one transaction.
create or replace function public.connect_submit_proposal(
  p_to_user_id uuid, p_need_id uuid, p_amount numeric, p_currency text,
  p_timeline_days integer, p_message text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare v_id uuid := gen_random_uuid();
begin
  if p_to_user_id is null or p_to_user_id = auth.uid() then raise exception 'ACTION_NOT_ALLOWED'; end if;
  perform public.connect_spend_credits('proposal', 'connect_proposal', v_id, 'proposal:' || v_id::text);
  insert into public.connect_proposals
    (id, from_user_id, to_user_id, need_id, amount, currency, timeline_days, message, status)
  values (v_id, auth.uid(), p_to_user_id, p_need_id, coalesce(p_amount, 0), coalesce(nullif(p_currency, ''), 'USD'),
    p_timeline_days, coalesce(p_message, ''), 'pending');
  return v_id;
end;
$$;

create or replace function public.connect_send_request(
  p_to_user_id uuid, p_target_profile_id uuid, p_target_need_id uuid, p_message text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare v_id uuid := gen_random_uuid();
begin
  if p_to_user_id is null or p_to_user_id = auth.uid() then raise exception 'ACTION_NOT_ALLOWED'; end if;
  perform public.connect_spend_credits('contact', 'connect_request', v_id, 'contact:' || v_id::text);
  insert into public.connect_requests
    (id, from_user_id, to_user_id, target_profile_id, target_need_id, message, status)
  values (v_id, auth.uid(), p_to_user_id, p_target_profile_id, p_target_need_id, coalesce(p_message, ''), 'pending');
  return v_id;
end;
$$;

create or replace function public.connect_publish_need(
  p_title text, p_summary text, p_skills text[], p_budget_band text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare v_id uuid := gen_random_uuid();
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and account_type in ('client', 'admin')) then raise exception 'ACTION_NOT_ALLOWED'; end if;
  perform public.connect_spend_credits('publish_need', 'connect_need', v_id, 'publish_need:' || v_id::text);
  insert into public.connect_need_posts
    (id, client_user_id, title, summary, skills, budget_band, is_open, moderation_status)
  values (v_id, auth.uid(), left(coalesce(p_title, ''), 200), coalesce(p_summary, ''), coalesce(p_skills, '{}'),
    left(coalesce(p_budget_band, ''), 120), true, 'pending');
  return v_id;
end;
$$;

create or replace function public.connect_accept_proposal(p_proposal_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
begin
  update public.connect_proposals set status = 'accepted', updated_at = now()
    where id = p_proposal_id and to_user_id = auth.uid() and status = 'pending';
  if not found then raise exception 'ACTION_NOT_ALLOWED'; end if;
end;
$$;

create or replace function public.connect_transition_milestone(p_milestone_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public
as $$
declare v_m public.connect_milestones;
begin
  if p_status not in ('pending', 'funded', 'released', 'disputed', 'cancelled') then raise exception 'ACTION_NOT_ALLOWED'; end if;
  select * into v_m from public.connect_milestones where id = p_milestone_id for update;
  if not found or (v_m.client_user_id <> auth.uid() and v_m.freelancer_user_id <> auth.uid() and not public.is_admin()) then raise exception 'ACTION_NOT_ALLOWED'; end if;
  if p_status = 'released' and auth.uid() <> v_m.client_user_id and not public.is_admin() then raise exception 'ACTION_NOT_ALLOWED'; end if;
  update public.connect_milestones set status = p_status, updated_at = now(),
    released_at = case when p_status = 'released' then now() else released_at end,
    disputed_at = case when p_status = 'disputed' then now() else disputed_at end
    where id = p_milestone_id;
end;
$$;

create or replace function public.connect_submit_review(
  p_to_user_id uuid, p_request_id uuid, p_rating integer, p_body text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare v_id uuid := gen_random_uuid();
begin
  if p_rating < 1 or p_rating > 5 or p_to_user_id = auth.uid() then raise exception 'ACTION_NOT_ALLOWED'; end if;
  if not exists (
    select 1 from public.connect_milestones m
    join public.connect_requests r on r.id = m.engagement_request_id
    where r.id = p_request_id and m.status = 'released'
      and (r.from_user_id = auth.uid() or r.to_user_id = auth.uid())
  ) then raise exception 'ACTION_NOT_ALLOWED'; end if;
  insert into public.connect_reviews(id, from_user_id, to_user_id, request_id, rating, body)
    values (v_id, auth.uid(), p_to_user_id, p_request_id, p_rating, coalesce(p_body, ''));
  return v_id;
end;
$$;

create or replace function public.client_home_summary()
returns jsonb language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  return jsonb_build_object(
    'open_jobs', (select count(*) from public.connect_need_posts where client_user_id = auth.uid() and is_open = true),
    'pending_proposals', (select count(*) from public.connect_proposals where to_user_id = auth.uid() and status = 'pending'),
    'milestones_needing_action', (select count(*) from public.connect_milestones where client_user_id = auth.uid() and status = 'funded'),
    'unread_messages', (select count(*) from public.client_messages where to_uid = auth.uid() and is_read = false)
  );
end;
$$;

create or replace function public.freelancer_home_summary()
returns jsonb language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  return jsonb_build_object(
    'pending_proposals', (select count(*) from public.connect_proposals where from_user_id = auth.uid() and status = 'pending'),
    'accepted_proposals', (select count(*) from public.connect_proposals where from_user_id = auth.uid() and status = 'accepted'),
    'active_milestones', (select count(*) from public.connect_milestones where freelancer_user_id = auth.uid() and status in ('funded', 'disputed')),
    'unread_messages', (select count(*) from public.client_messages where to_uid = auth.uid() and is_read = false)
  );
end;
$$;

grant execute on function public.connect_submit_proposal(uuid, uuid, numeric, text, integer, text) to authenticated;
grant execute on function public.connect_send_request(uuid, uuid, uuid, text) to authenticated;
grant execute on function public.connect_publish_need(text, text, text[], text) to authenticated;
grant execute on function public.connect_accept_proposal(uuid) to authenticated;
grant execute on function public.connect_transition_milestone(uuid, text) to authenticated;
grant execute on function public.connect_submit_review(uuid, uuid, integer, text) to authenticated;
grant execute on function public.client_home_summary() to authenticated;
grant execute on function public.freelancer_home_summary() to authenticated;

create or replace function public.connect_publish_profile(
  p_headline text, p_bio text, p_skills text[], p_rate numeric)
returns uuid language plpgsql security definer set search_path = public
as $$
declare v_id uuid := auth.uid();
begin
  if v_id is null or not exists (select 1 from public.profiles where id = v_id and account_type = 'freelancer') then
    raise exception 'ACTION_NOT_ALLOWED';
  end if;
  perform public.connect_spend_credits('publish_profile', 'connect_profile', v_id, 'publish_profile:' || v_id::text);
  insert into public.connect_profiles (user_id, display_title, headline, bio, skills, rate_band, is_listed)
    values (v_id, left(coalesce(p_headline, ''), 200), left(coalesce(p_headline, ''), 200), coalesce(p_bio, ''), coalesce(p_skills, '{}'),
      left(coalesce(p_rate, 0)::text, 80), true)
  on conflict (user_id) do update set headline = excluded.headline, bio = excluded.bio,
    skills = excluded.skills, rate_band = excluded.rate_band, is_listed = true, updated_at = now();
  return v_id;
end;
$$;

create or replace function public.admin_dashboard_summary()
returns jsonb language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'ACTION_NOT_ALLOWED'; end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'open_jobs', (select count(*) from public.connect_need_posts where is_open = true),
    'pending_proposals', (select count(*) from public.connect_proposals where status = 'pending'));
end;
$$;

create or replace function public.record_product_event(p_name text, p_properties jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null or p_name is null or length(trim(p_name)) = 0 then raise exception 'ACTION_NOT_ALLOWED'; end if;
  insert into public.clivora_events (event_type, user_email, user_name, plan, payload, source)
    select left(trim(p_name), 80), coalesce(u.email, ''), coalesce(p.name, ''),
      coalesce(p.subscription_plan, 'free'), coalesce(p_properties, '{}'::jsonb), 'web'
    from auth.users u left join public.profiles p on p.id = u.id where u.id = auth.uid();
end;
$$;

grant execute on function public.connect_publish_profile(text, text, text[], numeric) to authenticated;
grant execute on function public.admin_dashboard_summary() to authenticated;
grant execute on function public.record_product_event(text, jsonb) to authenticated;
