-- CLIVORA v2.3.5 — Supabase advisor security fixes

-- Fix mutable search_path on lock_profile_account_type
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

-- Revoke public/anon RPC access to internal SECURITY DEFINER helpers
revoke all on function public.handle_new_user() from public, anon;
revoke all on function public.is_admin() from public, anon;
revoke all on function public.my_email() from public, anon;
revoke all on function public.uid_for_linked_email(text) from public, anon;
revoke all on function public.rls_auto_enable() from public, anon;
revoke all on function public.finalize_account_type(text, text) from public, anon;

grant execute on function public.finalize_account_type(text, text) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.my_email() to authenticated;
grant execute on function public.uid_for_linked_email(text) to authenticated;

-- Tighten analytics insert: users may only log events for their own email
drop policy if exists events_insert on public.clivora_events;
create policy events_insert on public.clivora_events
  for insert to authenticated
  with check (
    lower(coalesce(user_email, '')) = public.my_email()
    or public.is_admin()
  );
