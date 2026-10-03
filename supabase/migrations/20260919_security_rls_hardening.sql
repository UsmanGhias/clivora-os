-- 20260919_security_rls_hardening.sql
-- Formally enforce Row Level Security and explicit access policies
-- for app_feature_flags and automation_run_log in repository migrations.

-- 1. App Feature Flags
alter table if exists public.app_feature_flags enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'public' 
      and tablename = 'app_feature_flags' 
      and policyname = 'feature_flags_read'
  ) then
    create policy feature_flags_read 
      on public.app_feature_flags 
      for select 
      using (true);
  end if;
end $$;

-- Revoke unauthorized write access; only service_role or admin can modify flags
revoke insert, update, delete on public.app_feature_flags from anon, authenticated;

-- 2. Automation Run Log
alter table if exists public.automation_run_log enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where schemaname = 'public' 
      and tablename = 'automation_run_log' 
      and policyname = 'automation_run_log_own'
  ) then
    create policy automation_run_log_own 
      on public.automation_run_log 
      for all 
      using ((select auth.uid()) = user_uid)
      with check ((select auth.uid()) = user_uid);
  end if;
end $$;
