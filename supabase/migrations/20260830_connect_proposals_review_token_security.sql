-- CLIVORA Connect Proposals — Secure Magic Review Links & Read Receipts
-- Closes global token-scoped RLS leak on connect_proposals (matches invoice_shares pattern).
-- The magic review token is consumed via a SECURITY DEFINER function that takes
-- the secret token as an argument and returns only the single matching proposal.

begin;

-- 1. Ensure columns exist
alter table public.connect_proposals alter column to_user_id drop not null;

alter table public.connect_proposals
  add column if not exists review_token text unique,
  add column if not exists job_id uuid references public.connect_jobs(id) on delete set null,
  add column if not exists is_viewed boolean not null default false,
  add column if not exists viewed_at timestamptz,
  add column if not exists client_email text,
  add column if not exists client_name text;

create index if not exists idx_connect_proposals_review_token
  on public.connect_proposals (review_token) where review_token is not null;

create index if not exists idx_connect_proposals_job_id
  on public.connect_proposals (job_id) where job_id is not null;

-- 2. Drop the overly permissive policies that allow dumping the whole connect_proposals table
drop policy if exists connect_proposals_review_token_select on public.connect_proposals;
drop policy if exists connect_proposals_review_token_update on public.connect_proposals;

-- 3. Create secure token-scoped function for candidate review by magic link
create or replace function public.connect_proposal_by_review_token(p_token text)
returns table (
  id uuid,
  job_id uuid,
  amount numeric,
  currency text,
  timeline_days integer,
  message text,
  status text,
  is_viewed boolean,
  viewed_at timestamptz,
  client_name text,
  client_email text,
  created_at timestamptz,
  freelancer_id uuid,
  freelancer_name text,
  freelancer_avatar_url text,
  job_title text,
  job_company text,
  job_category text,
  job_salary_min integer,
  job_salary_max integer
) language plpgsql security definer set search_path to 'public' as $fn$
declare
  v_prop record;
begin
  if p_token is null or length(trim(p_token)) = 0 then
    return;
  end if;

  select p.* into v_prop
  from public.connect_proposals p
  where p.review_token = trim(p_token)
  limit 1;

  if not found then
    return;
  end if;

  -- Mark as viewed if not already marked (read receipt)
  if not coalesce(v_prop.is_viewed, false) then
    update public.connect_proposals
    set is_viewed = true,
        viewed_at = now(),
        status = case when status = 'pending' then 'viewed' else status end,
        updated_at = now()
    where public.connect_proposals.id = v_prop.id;

    v_prop.is_viewed := true;
    v_prop.viewed_at := now();
    v_prop.status := case when v_prop.status = 'pending' then 'viewed' else v_prop.status end;
  end if;

  return query
  select
    v_prop.id,
    v_prop.job_id,
    v_prop.amount,
    v_prop.currency,
    v_prop.timeline_days,
    v_prop.message,
    v_prop.status,
    v_prop.is_viewed,
    v_prop.viewed_at,
    v_prop.client_name,
    v_prop.client_email,
    v_prop.created_at,
    v_prop.from_user_id as freelancer_id,
    coalesce(prof.name, 'Verified Freelancer')::text as freelancer_name,
    prof.avatar_url::text as freelancer_avatar_url,
    coalesce(j.title, 'Project Opportunity')::text as job_title,
    coalesce(j.company_name, v_prop.client_name, '')::text as job_company,
    coalesce(j.category, 'general')::text as job_category,
    j.salary_min as job_salary_min,
    j.salary_max as job_salary_max
  from public.profiles prof
  left join public.connect_jobs j on j.id = v_prop.job_id
  where prof.id = v_prop.from_user_id;
end;
$fn$;

revoke all on function public.connect_proposal_by_review_token(text) from public;
grant execute on function public.connect_proposal_by_review_token(text) to anon, authenticated;

commit;
