-- Align grant_pro_by_email with web admin grant-pro API: free | pro | pro_plus
-- Applies to freelancer and client profiles alike.

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

  if v_plan in ('plus', 'proplus') then
    v_plan := 'pro_plus';
  end if;

  if v_plan not in ('pro', 'pro_plus', 'free') then
    raise exception 'Plan must be free, pro, or pro_plus.';
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

  if v_plan in ('pro', 'pro_plus') then
    delete from public.subscriptions
    where user_id = v_target and product_id like 'admin_grant_%';

    insert into public.subscriptions (user_id, product_id, purchase_token, status, expires_at, verified_at)
    values (
      v_target,
      'admin_grant_' || v_plan,
      'admin_' || v_target::text || '_' || v_plan || '_' || extract(epoch from now())::bigint::text,
      'active',
      now() + interval '1 year',
      now()
    );
  else
    update public.subscriptions
      set status = 'canceled', updated_at = now()
    where user_id = v_target and status = 'active';
  end if;
end;
$$;

revoke all on function public.grant_pro_by_email(text, text) from public, anon;
grant execute on function public.grant_pro_by_email(text, text) to authenticated;
