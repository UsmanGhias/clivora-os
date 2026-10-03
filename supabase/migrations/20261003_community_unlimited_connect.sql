-- CLIVORA Community edition: Connect has no paid credit allowance.
--
-- Every Connect credit account is unlimited. Actions are still written to the
-- ledger (with amount 0), and the eligibility checks in connect_spend_credits
-- (confirmed email, profile completeness, not blocked) still apply.
--
-- 'infinity' matters: connect_prepare_credit_account used to downgrade an
-- unlimited account once grandfather_until had passed, and treated null as passed.

create or replace function public.connect_prepare_credit_account(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_uid <> auth.uid() and not public.is_admin() then
    raise exception 'ACTION_NOT_ALLOWED';
  end if;

  insert into public.connect_credit_accounts
    (user_id, plan, allowance, balance, current_period_start, current_period_end,
     legacy_unlimited, grandfather_until)
  values
    (p_uid, 'community', 0, 0, now(), 'infinity', true, 'infinity')
  on conflict (user_id) do update
    set legacy_unlimited = true,
        grandfather_until = 'infinity',
        updated_at = now();
end;
$$;

update public.connect_credit_accounts
   set legacy_unlimited = true,
       grandfather_until = 'infinity',
       updated_at = now();
