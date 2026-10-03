-- Protect profiles privileged columns (additive, idempotent).
-- Exported from live Supabase (protect_profiles_privileged_columns).
-- See docs/internal/ISSUE_MAP.md SEC-1
--
-- Note: profiles also has legacy triggers profiles_guard_privileged_columns and
-- profiles_lock_account_type from earlier migrations; this adds the SMEMaster trigger.

begin;

create or replace function public.profiles_protect_privileged_columns()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if public.is_admin() then
    return new;
  end if;
  if new.role is distinct from old.role then
    raise exception 'cannot change role';
  end if;
  if new.account_type is distinct from old.account_type
     and old.account_type is not null
     and old.account_type <> '' then
    raise exception 'cannot change account_type';
  end if;
  if new.is_blocked is distinct from old.is_blocked then
    raise exception 'cannot change is_blocked';
  end if;
  if new.is_restricted is distinct from old.is_restricted then
    raise exception 'cannot change is_restricted';
  end if;
  if new.subscription_plan is distinct from old.subscription_plan then
    raise exception 'cannot change subscription_plan';
  end if;
  return new;
end;
$function$;

drop trigger if exists profiles_protect_privileged_columns_trg on public.profiles;
create trigger profiles_protect_privileged_columns_trg
  before update on public.profiles
  for each row execute function public.profiles_protect_privileged_columns();

commit;
