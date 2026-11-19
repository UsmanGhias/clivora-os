-- Migration: 20261119_rpc_and_policy_hardening.sql
-- Description:
-- 1. Restrict anonymous execution on sensitive SECURITY DEFINER procedures.
-- 2. Consolidate multiple permissive RLS policies and optimize auth evaluation
--    on connect_jobs, crm_time_entries, invoice_shares, project_shares, promo_codes, and quote_shares.

-- ============================================================================
-- PART 1: REVOKE PUBLIC / ANON EXECUTION ON SENSITIVE SECURITY DEFINER FUNCTIONS
-- ============================================================================

REVOKE ALL ON FUNCTION public.connect_auto_approve_enabled(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.connect_auto_approve_enabled(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.connect_credit_eligible(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.connect_credit_eligible(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.connect_credit_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.connect_credit_summary() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.connect_peer_contact(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.connect_peer_contact(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.connect_prepare_credit_account(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.connect_prepare_credit_account(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.connect_refund_moderated_action(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.connect_refund_moderated_action(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.connect_send_request(uuid, uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.connect_send_request(uuid, uuid, uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.connect_submit_review(uuid, uuid, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.connect_submit_review(uuid, uuid, integer, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.crm_plan_is_paid(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crm_plan_is_paid(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.refresh_connect_reputation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_connect_reputation(uuid) TO authenticated, service_role;

-- ============================================================================
-- PART 2: CONSOLIDATE MULTIPLE PERMISSIVE POLICIES AND OPTIMIZE RLS INITPLANS
-- ============================================================================

-- Table 1: connect_jobs
DROP POLICY IF EXISTS "connect_jobs_admin_read" ON public.connect_jobs;
DROP POLICY IF EXISTS "connect_jobs_owner_read" ON public.connect_jobs;
DROP POLICY IF EXISTS "connect_jobs_public_read" ON public.connect_jobs;

CREATE POLICY "connect_jobs_select_anon"
  ON public.connect_jobs
  FOR SELECT
  TO anon
  USING ((is_public = true) AND (status = 'published'));

CREATE POLICY "connect_jobs_select_authenticated"
  ON public.connect_jobs
  FOR SELECT
  TO authenticated
  USING (
    (select is_admin())
    OR (posted_by = (select auth.uid()))
    OR (claimed_by = (select auth.uid()))
    OR ((is_public = true) AND (status = 'published'))
  );

-- Table 2: crm_time_entries
DROP POLICY IF EXISTS "crm_time_entries_owner" ON public.crm_time_entries;
DROP POLICY IF EXISTS "crm_time_entries_shared_client_select" ON public.crm_time_entries;
DROP POLICY IF EXISTS "crm_time_entries_shared_client_update" ON public.crm_time_entries;

CREATE POLICY "crm_time_entries_insert"
  ON public.crm_time_entries
  FOR INSERT
  TO authenticated
  WITH CHECK (owner_uid = (select auth.uid()));

CREATE POLICY "crm_time_entries_delete"
  ON public.crm_time_entries
  FOR DELETE
  TO authenticated
  USING (owner_uid = (select auth.uid()));

CREATE POLICY "crm_time_entries_select"
  ON public.crm_time_entries
  FOR SELECT
  TO authenticated
  USING (
    owner_uid = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.project_shares ps
      WHERE ps.freelancer_uid = crm_time_entries.owner_uid
        AND (ps.client_uid = (select auth.uid()) OR lower(ps.client_email) = lower(coalesce((select my_email()), '')))
    )
  );

CREATE POLICY "crm_time_entries_update"
  ON public.crm_time_entries
  FOR UPDATE
  TO authenticated
  USING (
    owner_uid = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.project_shares ps
      WHERE ps.freelancer_uid = crm_time_entries.owner_uid
        AND (ps.client_uid = (select auth.uid()) OR lower(ps.client_email) = lower(coalesce((select my_email()), '')))
    )
  )
  WITH CHECK (
    owner_uid = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.project_shares ps
      WHERE ps.freelancer_uid = crm_time_entries.owner_uid
        AND (ps.client_uid = (select auth.uid()) OR lower(ps.client_email) = lower(coalesce((select my_email()), '')))
    )
  );

-- Table 3: invoice_shares
DROP POLICY IF EXISTS "invoice_shares_write" ON public.invoice_shares;
DROP POLICY IF EXISTS "invoice_shares_select" ON public.invoice_shares;
DROP POLICY IF EXISTS "invoice_shares_client_pay" ON public.invoice_shares;

CREATE POLICY "invoice_shares_insert"
  ON public.invoice_shares
  FOR INSERT
  TO authenticated
  WITH CHECK ((select is_admin()) OR freelancer_uid = (select auth.uid()));

CREATE POLICY "invoice_shares_delete"
  ON public.invoice_shares
  FOR DELETE
  TO authenticated
  USING ((select is_admin()) OR freelancer_uid = (select auth.uid()));

CREATE POLICY "invoice_shares_select"
  ON public.invoice_shares
  FOR SELECT
  TO authenticated
  USING (
    (select is_admin())
    OR freelancer_uid = (select auth.uid())
    OR client_uid = (select auth.uid())
    OR client_email = (select my_email())
  );

CREATE POLICY "invoice_shares_update"
  ON public.invoice_shares
  FOR UPDATE
  TO authenticated
  USING (
    (select is_admin())
    OR freelancer_uid = (select auth.uid())
    OR client_uid = (select auth.uid())
    OR client_email = (select my_email())
  )
  WITH CHECK (
    (select is_admin())
    OR freelancer_uid = (select auth.uid())
    OR client_uid = (select auth.uid())
    OR client_email = (select my_email())
  );

-- Table 4: project_shares
DROP POLICY IF EXISTS "shares_write" ON public.project_shares;
DROP POLICY IF EXISTS "shares_select" ON public.project_shares;
DROP POLICY IF EXISTS "shares_client_link" ON public.project_shares;

CREATE POLICY "project_shares_insert"
  ON public.project_shares
  FOR INSERT
  TO authenticated
  WITH CHECK ((select is_admin()) OR freelancer_uid = (select auth.uid()));

CREATE POLICY "project_shares_delete"
  ON public.project_shares
  FOR DELETE
  TO authenticated
  USING ((select is_admin()) OR freelancer_uid = (select auth.uid()));

CREATE POLICY "project_shares_select"
  ON public.project_shares
  FOR SELECT
  TO authenticated
  USING (
    (select is_admin())
    OR freelancer_uid = (select auth.uid())
    OR client_uid = (select auth.uid())
    OR client_email = (select my_email())
  );

CREATE POLICY "project_shares_update"
  ON public.project_shares
  FOR UPDATE
  TO authenticated
  USING (
    (select is_admin())
    OR freelancer_uid = (select auth.uid())
    OR client_email = (select my_email())
  );

-- Table 5: promo_codes
DROP POLICY IF EXISTS "promo_codes_admin" ON public.promo_codes;
DROP POLICY IF EXISTS "promo_codes_read_active" ON public.promo_codes;

CREATE POLICY "promo_codes_insert"
  ON public.promo_codes
  FOR INSERT
  TO authenticated
  WITH CHECK ((select is_admin()));

CREATE POLICY "promo_codes_update"
  ON public.promo_codes
  FOR UPDATE
  TO authenticated
  USING ((select is_admin()))
  WITH CHECK ((select is_admin()));

CREATE POLICY "promo_codes_delete"
  ON public.promo_codes
  FOR DELETE
  TO authenticated
  USING ((select is_admin()));

CREATE POLICY "promo_codes_select_anon"
  ON public.promo_codes
  FOR SELECT
  TO anon
  USING (is_active = true AND (expires_at IS NULL OR expires_at > now()));

CREATE POLICY "promo_codes_select_authenticated"
  ON public.promo_codes
  FOR SELECT
  TO authenticated
  USING ((select is_admin()) OR (is_active = true AND (expires_at IS NULL OR expires_at > now())));

-- Table 6: quote_shares
DROP POLICY IF EXISTS "quote_shares_write" ON public.quote_shares;
DROP POLICY IF EXISTS "quote_shares_select" ON public.quote_shares;
DROP POLICY IF EXISTS "quote_shares_client_update" ON public.quote_shares;

CREATE POLICY "quote_shares_insert"
  ON public.quote_shares
  FOR INSERT
  TO authenticated
  WITH CHECK ((select is_admin()) OR freelancer_uid = (select auth.uid()));

CREATE POLICY "quote_shares_delete"
  ON public.quote_shares
  FOR DELETE
  TO authenticated
  USING ((select is_admin()) OR freelancer_uid = (select auth.uid()));

CREATE POLICY "quote_shares_select"
  ON public.quote_shares
  FOR SELECT
  TO authenticated
  USING (
    (select is_admin())
    OR freelancer_uid = (select auth.uid())
    OR client_uid = (select auth.uid())
    OR lower(client_email) = lower(coalesce((select my_email()), ''))
  );

CREATE POLICY "quote_shares_update"
  ON public.quote_shares
  FOR UPDATE
  TO authenticated
  USING (
    (select is_admin())
    OR freelancer_uid = (select auth.uid())
    OR client_uid = (select auth.uid())
    OR lower(client_email) = lower(coalesce((select my_email()), ''))
  )
  WITH CHECK (
    (select is_admin())
    OR freelancer_uid = (select auth.uid())
    OR client_uid = (select auth.uid())
    OR lower(client_email) = lower(coalesce((select my_email()), ''))
  );
