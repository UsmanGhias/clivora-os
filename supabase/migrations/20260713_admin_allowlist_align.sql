-- Admin allowlist is table-driven (public.admin_allowlist, created in 007).
-- This migration is kept so migration history stays aligned; it re-asserts the function.
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
