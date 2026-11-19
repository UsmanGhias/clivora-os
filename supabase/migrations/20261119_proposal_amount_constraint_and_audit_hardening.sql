-- 20261119_proposal_amount_constraint_and_audit_hardening.sql
-- Schema hardening: Enforce positive proposal bids, full-text job discovery indexing, event payload validation, and RLS policies.

-- 1. Enforce Proposal Amount Integrity
-- Update legacy or zero-bid entries to 1 USD prior to applying constraint
UPDATE public.connect_proposals 
SET amount = 1 
WHERE amount <= 0 OR amount IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'connect_proposals_positive_amount'
  ) THEN
    ALTER TABLE public.connect_proposals 
      ADD CONSTRAINT connect_proposals_positive_amount CHECK (amount > 0);
  END IF;
END $$;

-- 2. Optimize Job Discovery Layer with GIN Full-Text Search and Foreign Key Covering Indexes
CREATE INDEX IF NOT EXISTS idx_jobs_active_search 
ON public.connect_jobs USING gin (to_tsvector('english', title || ' ' || coalesce(description, ''))) 
WHERE status = 'published';

CREATE INDEX IF NOT EXISTS idx_connect_jobs_claimed_by 
ON public.connect_jobs (claimed_by) 
WHERE claimed_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_connect_jobs_posted_by 
ON public.connect_jobs (posted_by) 
WHERE posted_by IS NOT NULL;

-- 3. Audit Trail Payload Integrity
-- Backfill empty events with structured metadata
UPDATE public.clivora_events 
SET payload = jsonb_build_object('event', event_type, 'legacy_backfill', true, 'cleaned_at', now()) 
WHERE payload IS NULL OR payload = '{}'::jsonb OR payload = 'null'::jsonb;

-- Reject unpopulated empty telemetry events at database constraint level
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'clivora_events_valid_payload'
  ) THEN
    ALTER TABLE public.clivora_events 
      ADD CONSTRAINT clivora_events_valid_payload CHECK (payload IS NOT NULL AND payload <> '{}'::jsonb);
  END IF;
END $$;

-- 4. Invoice Audit Timestamps
ALTER TABLE public.crm_invoices 
ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- 5. Fix Mutable Function Search Path
ALTER FUNCTION public.process_outreach_clients_batch(integer) SET search_path = public, pg_temp;

-- 6. RLS Policies for Unprotected Internal / Admin Tables
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = '_internal_secrets' AND policyname = 'internal_secrets_admin') THEN
    CREATE POLICY internal_secrets_admin ON public._internal_secrets FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = '_outreach_client_staging' AND policyname = 'staging_client_admin') THEN
    CREATE POLICY staging_client_admin ON public._outreach_client_staging FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = '_outreach_freelancer_staging' AND policyname = 'staging_freelancer_admin') THEN
    CREATE POLICY staging_freelancer_admin ON public._outreach_freelancer_staging FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'admin_integration_secrets' AND policyname = 'admin_secrets_admin') THEN
    CREATE POLICY admin_secrets_admin ON public.admin_integration_secrets FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'promo_codes' AND policyname = 'promo_codes_admin') THEN
    CREATE POLICY promo_codes_admin ON public.promo_codes FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'promo_codes' AND policyname = 'promo_codes_read_active') THEN
    CREATE POLICY promo_codes_read_active ON public.promo_codes FOR SELECT TO authenticated, anon USING (is_active = true AND (expires_at IS NULL OR expires_at > now()));
  END IF;
END $$;


