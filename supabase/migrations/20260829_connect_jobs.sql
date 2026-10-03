-- CLIVORA Connect Jobs — Public Job Board & Autonomous Crawler Schema
-- Migration: 20260829_connect_jobs.sql
-- Creates the `connect_jobs` table for external job feed ingestion,
-- public SEO job board, and auto-client provisioning pipeline.

begin;

-- ---------------------------------------------------------------------------
-- connect_jobs: unified job listing table for crawled + manual postings
-- ---------------------------------------------------------------------------
create table if not exists public.connect_jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  company_name text not null default '',
  company_domain text,
  company_email text,
  description text not null default '',
  category text not null default 'general',
  tags text[] not null default '{}',
  salary_min integer,
  salary_max integer,
  currency text not null default 'USD',
  location text not null default 'Remote',
  job_type text not null default 'full_time'
    check (job_type in ('full_time', 'part_time', 'contract', 'freelance', 'internship')),
  source text not null default 'manual'
    check (source in ('manual', 'remotive', 'arbeitnow', 'hackernews', 'import')),
  source_id text,
  source_url text,
  seo_slug text not null unique,
  status text not null default 'draft'
    check (status in ('draft', 'published', 'expired', 'removed')),
  is_public boolean not null default false,
  posted_by uuid references auth.users(id) on delete set null,
  claimed_by uuid references auth.users(id) on delete set null,
  claim_token text unique,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source, source_id)
);

-- Performance indexes
create index if not exists connect_jobs_category_status_idx
  on public.connect_jobs (category, status) where is_public = true;
create index if not exists connect_jobs_slug_idx
  on public.connect_jobs (seo_slug);
create index if not exists connect_jobs_company_domain_idx
  on public.connect_jobs (company_domain) where company_domain is not null;
create index if not exists connect_jobs_created_idx
  on public.connect_jobs (created_at desc) where status = 'published';
create index if not exists connect_jobs_tags_idx
  on public.connect_jobs using gin (tags);

-- ---------------------------------------------------------------------------
-- RLS: public read for published jobs; owner/admin write
-- ---------------------------------------------------------------------------
alter table public.connect_jobs enable row level security;

-- Anyone (including anon) can read published public jobs
drop policy if exists connect_jobs_public_read on public.connect_jobs;
create policy connect_jobs_public_read on public.connect_jobs
  for select to anon, authenticated
  using (is_public = true and status = 'published');

-- Authenticated users can read their own jobs (any status)
drop policy if exists connect_jobs_owner_read on public.connect_jobs;
create policy connect_jobs_owner_read on public.connect_jobs
  for select to authenticated
  using (posted_by = (select auth.uid()) or claimed_by = (select auth.uid()));

-- Admin can read all jobs
drop policy if exists connect_jobs_admin_read on public.connect_jobs;
create policy connect_jobs_admin_read on public.connect_jobs
  for select to authenticated
  using (public.is_admin());

-- Authenticated users can insert their own jobs
drop policy if exists connect_jobs_insert on public.connect_jobs;
create policy connect_jobs_insert on public.connect_jobs
  for insert to authenticated
  with check (posted_by = (select auth.uid()) or public.is_admin());

-- Owner or admin can update
drop policy if exists connect_jobs_update on public.connect_jobs;
create policy connect_jobs_update on public.connect_jobs
  for update to authenticated
  using (posted_by = (select auth.uid()) or claimed_by = (select auth.uid()) or public.is_admin())
  with check (posted_by = (select auth.uid()) or claimed_by = (select auth.uid()) or public.is_admin());

-- Admin only can delete
drop policy if exists connect_jobs_delete on public.connect_jobs;
create policy connect_jobs_delete on public.connect_jobs
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- RPC: public job lookup by slug (for SEO pages, no RLS bypass needed)
-- ---------------------------------------------------------------------------
create or replace function public.connect_job_by_slug(p_slug text)
returns table(
  id uuid, title text, company_name text, description text, category text,
  tags text[], salary_min integer, salary_max integer, currency text,
  location text, job_type text, source_url text, seo_slug text,
  created_at timestamptz
) language plpgsql security definer set search_path to 'public' as $fn$
begin
  return query
  select j.id, j.title, j.company_name, j.description, j.category,
         j.tags, j.salary_min, j.salary_max, j.currency,
         j.location, j.job_type, j.source_url, j.seo_slug,
         j.created_at
  from public.connect_jobs j
  where j.seo_slug = p_slug and j.is_public = true and j.status = 'published'
  limit 1;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- RPC: claim a job listing via token
-- ---------------------------------------------------------------------------
create or replace function public.connect_job_claim(p_token text)
returns jsonb language plpgsql security definer set search_path to 'public' as $fn$
declare
  v_job record;
begin
  select * into v_job from public.connect_jobs
  where claim_token = p_token and claimed_by is null
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid_or_claimed');
  end if;

  update public.connect_jobs
  set claimed_by = (select auth.uid()), claim_token = null, updated_at = now()
  where id = v_job.id;

  return jsonb_build_object('ok', true, 'job_id', v_job.id, 'title', v_job.title);
end;
$fn$;

revoke all on function public.connect_job_by_slug(text) from public;
grant execute on function public.connect_job_by_slug(text) to anon, authenticated;

revoke all on function public.connect_job_claim(text) from public;
grant execute on function public.connect_job_claim(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Add connect_jobs to supabase_realtime publication
-- Also add tables needed for Phase 1.6 Realtime sync
-- ---------------------------------------------------------------------------
do $$
begin
  -- connect_jobs
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'connect_jobs'
  ) then
    alter publication supabase_realtime add table public.connect_jobs;
  end if;

  -- crm_customers (for realtime sync)
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'crm_customers'
  ) then
    alter publication supabase_realtime add table public.crm_customers;
  end if;

  -- crm_projects (for realtime sync)
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'crm_projects'
  ) then
    alter publication supabase_realtime add table public.crm_projects;
  end if;

  -- crm_invoices (for realtime sync)
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'crm_invoices'
  ) then
    alter publication supabase_realtime add table public.crm_invoices;
  end if;

  -- workspace_tasks (for realtime sync)
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'workspace_tasks'
  ) then
    alter publication supabase_realtime add table public.workspace_tasks;
  end if;

  -- profiles (for realtime subscription parity)
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
end $$;

commit;
