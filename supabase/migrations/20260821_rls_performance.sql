-- RLS and index performance pass (Sprint 3 audit).
--
-- Three findings, all measured against the live schema:
--
--   1. 92 of 106 policies in `public` called auth.uid() (and the STABLE
--      SECURITY DEFINER helpers is_admin / is_super_admin / is_pro_plus /
--      my_email / crm_plan_is_paid / is_allowlisted_admin) directly in the
--      USING/WITH CHECK expression. Postgres then re-evaluates the call for
--      every candidate row. Wrapping each call in a scalar subquery lets the
--      planner hoist it into an InitPlan that runs once per statement.
--
--      The helpers are all provolatile = 's' (STABLE) and take no arguments, so
--      hoisting them is semantically identical, not just cheaper.
--
--   2. 50 foreign keys had no covering index. Every one of them makes the
--      parent-side DELETE/UPDATE do a sequential scan of the child table, and
--      most are also the column the app filters on (owner_uid, customer_id,
--      project_id).
--
--   3. automation_webhook_queue had two identical partial unique indexes on
--      idempotency_key.

begin;

-- ---------------------------------------------------------------------------
-- 1. Hoist per-row auth calls out of every policy
-- ---------------------------------------------------------------------------
-- Driven off pg_policies rather than a hand-written list, because the live
-- schema has known drift from the migration history (see docs/audit/schema-drift.md).
-- The transform is idempotent: it first unwraps anything already wrapped, then
-- wraps every call exactly once, so re-running is a no-op.

do $$
declare
  pol record;
  new_qual text;
  new_check text;
  -- No name here is a substring of another, so plain replace() is safe.
  calls text[] := array[
    'auth.uid()', 'auth.jwt()',
    'is_admin()', 'is_super_admin()', 'is_pro_plus()', 'my_email()',
    'crm_plan_is_paid()', 'is_allowlisted_admin()'
  ];
  fn text;
  pat text;
  changed int := 0;
begin
  for pol in
    select tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
  loop
    new_qual := pol.qual;
    new_check := pol.with_check;

    foreach fn in array calls
    loop
      -- Unwrap first. Postgres decompiles an existing scalar subquery as
      -- "( SELECT auth.uid() AS uid )", so match that shape loosely.
      pat := '\(\s*SELECT\s+'
             || replace(replace(replace(fn, '.', '\.'), '(', '\('), ')', '\)')
             || '\s*(AS\s+\w+\s*)?\)';

      new_qual := regexp_replace(new_qual, pat, fn, 'gi');
      new_check := regexp_replace(new_check, pat, fn, 'gi');

      -- Then wrap every remaining call exactly once.
      new_qual := replace(new_qual, fn, '(select ' || fn || ')');
      new_check := replace(new_check, fn, '(select ' || fn || ')');
    end loop;

    if new_qual is not distinct from pol.qual
       and new_check is not distinct from pol.with_check then
      continue;
    end if;

    execute format(
      'alter policy %I on public.%I%s%s',
      pol.policyname,
      pol.tablename,
      case when new_qual is not null then ' using (' || new_qual || ')' else '' end,
      case when new_check is not null then ' with check (' || new_check || ')' else '' end
    );
    changed := changed + 1;
  end loop;

  raise notice 'rls_performance: rewrote % policies', changed;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Cover every foreign key
-- ---------------------------------------------------------------------------
-- Plain CREATE INDEX rather than CONCURRENTLY so the whole migration stays in
-- one transaction. Safe at current table sizes; revisit if any of these grows
-- past a few hundred thousand rows.

create index if not exists idx_admin_integration_secrets_updated_by on public.admin_integration_secrets (updated_by);
create index if not exists idx_ai_suggestions_owner_uid on public.ai_suggestions (owner_uid);
create index if not exists idx_app_feature_flags_updated_by on public.app_feature_flags (updated_by);
create index if not exists idx_automation_rules_owner_uid on public.automation_rules (owner_uid);
create index if not exists idx_automation_run_log_user_uid on public.automation_run_log (user_uid);
create index if not exists idx_automation_webhook_queue_owner_uid on public.automation_webhook_queue (owner_uid);
create index if not exists idx_calendar_events_customer_id on public.calendar_events (customer_id);
create index if not exists idx_calendar_events_project_id on public.calendar_events (project_id);
create index if not exists idx_campaign_blocks_campaign_id on public.campaign_blocks (campaign_id);
create index if not exists idx_chat_blocks_blocked_uid on public.chat_blocks (blocked_uid);
create index if not exists idx_client_messages_from_uid on public.client_messages (from_uid);
create index if not exists idx_connect_milestones_client_user_id on public.connect_milestones (client_user_id);
create index if not exists idx_connect_milestones_engagement_request_id on public.connect_milestones (engagement_request_id);
create index if not exists idx_connect_milestones_freelancer_user_id on public.connect_milestones (freelancer_user_id);
create index if not exists idx_connect_need_posts_client_user_id on public.connect_need_posts (client_user_id);
create index if not exists idx_connect_proposals_from_user_id on public.connect_proposals (from_user_id);
create index if not exists idx_connect_proposals_need_id on public.connect_proposals (need_id);
create index if not exists idx_connect_proposals_request_id on public.connect_proposals (request_id);
create index if not exists idx_connect_proposals_to_user_id on public.connect_proposals (to_user_id);
create index if not exists idx_connect_requests_target_need_id on public.connect_requests (target_need_id);
create index if not exists idx_connect_requests_target_profile_id on public.connect_requests (target_profile_id);
create index if not exists idx_connect_reviews_request_id on public.connect_reviews (request_id);
create index if not exists idx_contract_signatures_owner_uid on public.contract_signatures (owner_uid);
create index if not exists idx_contract_signatures_signer_uid on public.contract_signatures (signer_uid);
create index if not exists idx_crm_activities_company_id on public.crm_activities (company_id);
create index if not exists idx_crm_customer_groups_group_id on public.crm_customer_groups (group_id);
create index if not exists idx_crm_customer_tags_tag_id on public.crm_customer_tags (tag_id);
create index if not exists idx_crm_customers_company_id on public.crm_customers (company_id);
create index if not exists idx_crm_customers_duplicate_of on public.crm_customers (duplicate_of);
create index if not exists idx_crm_invoices_customer_id on public.crm_invoices (customer_id);
create index if not exists idx_crm_invoices_project_id on public.crm_invoices (project_id);
create index if not exists idx_crm_notes_customer_id on public.crm_notes (customer_id);
create index if not exists idx_crm_notes_owner_uid on public.crm_notes (owner_uid);
create index if not exists idx_crm_notes_project_id on public.crm_notes (project_id);
create index if not exists idx_crm_payment_allocations_owner_uid on public.crm_payment_allocations (owner_uid);
create index if not exists idx_crm_projects_customer_id on public.crm_projects (customer_id);
create index if not exists idx_crm_time_entries_project_id on public.crm_time_entries (project_id);
create index if not exists idx_meeting_links_owner_uid on public.meeting_links (owner_uid);
create index if not exists idx_meeting_links_project_id on public.meeting_links (project_id);
create index if not exists idx_meeting_links_request_id on public.meeting_links (request_id);
create index if not exists idx_notifications_from_uid on public.notifications (from_uid);
create index if not exists idx_pro_payment_requests_user_id on public.pro_payment_requests (user_id);
create index if not exists idx_project_shares_freelancer_uid on public.project_shares (freelancer_uid);
create index if not exists idx_referral_redemptions_referrer_user_id on public.referral_redemptions (referrer_user_id);
create index if not exists idx_support_tickets_user_id on public.support_tickets (user_id);
create index if not exists idx_vault_share_links_owner_uid on public.vault_share_links (owner_uid);
create index if not exists idx_workspace_tasks_customer_id on public.workspace_tasks (customer_id);
create index if not exists idx_workspace_tasks_parent_task_id on public.workspace_tasks (parent_task_id);
create index if not exists idx_workspace_tasks_project_id on public.workspace_tasks (project_id);
create index if not exists idx_workspace_tasks_project_share_id on public.workspace_tasks (project_share_id);

-- ---------------------------------------------------------------------------
-- 3. Drop the duplicate index
-- ---------------------------------------------------------------------------
-- Identical to automation_webhook_queue_idem_uidx, which is kept.

drop index if exists public.automation_webhook_queue_idempotency_key_uidx;

commit;
