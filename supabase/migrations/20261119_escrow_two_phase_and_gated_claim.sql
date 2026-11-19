-- 20261119_escrow_two_phase_and_gated_claim.sql
-- Two-Phase Proposal Acceptance, Escrow Milestone State Machine, 14-Day Deterministic Auto-Release, and Gated Job Claim Flow

-- 1. Milestone Schema Hardening
DO $$
BEGIN
  -- Allow engagement_request_id to be nullable for marketplace job proposals
  ALTER TABLE public.connect_milestones ALTER COLUMN engagement_request_id DROP NOT NULL;

  -- Add proposal_id and job_id foreign keys if not exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'connect_milestones' AND column_name = 'proposal_id'
  ) THEN
    ALTER TABLE public.connect_milestones 
      ADD COLUMN proposal_id UUID REFERENCES public.connect_proposals(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'connect_milestones' AND column_name = 'job_id'
  ) THEN
    ALTER TABLE public.connect_milestones 
      ADD COLUMN job_id UUID REFERENCES public.connect_jobs(id) ON DELETE SET NULL;
  END IF;

  -- Add submitted_at and auto_release_scheduled
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'connect_milestones' AND column_name = 'submitted_at'
  ) THEN
    ALTER TABLE public.connect_milestones 
      ADD COLUMN submitted_at TIMESTAMPTZ;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'connect_milestones' AND column_name = 'auto_release_scheduled'
  ) THEN
    ALTER TABLE public.connect_milestones 
      ADD COLUMN auto_release_scheduled BOOLEAN DEFAULT false;
  END IF;

  -- Update status check constraint
  ALTER TABLE public.connect_milestones DROP CONSTRAINT IF EXISTS connect_milestones_status_chk;
  ALTER TABLE public.connect_milestones ADD CONSTRAINT connect_milestones_status_chk
    CHECK (status = ANY (ARRAY[
      'pending'::text,
      'pending_funding'::text,
      'funded'::text,
      'submitted'::text,
      'released'::text,
      'disputed'::text,
      'cancelled'::text
    ]));

  -- Indexes
  CREATE INDEX IF NOT EXISTS idx_connect_milestones_proposal_id ON public.connect_milestones(proposal_id);
  CREATE INDEX IF NOT EXISTS idx_connect_milestones_job_id ON public.connect_milestones(job_id);
  CREATE INDEX IF NOT EXISTS idx_connect_milestones_status_submitted ON public.connect_milestones(status, submitted_at) WHERE status = 'submitted';
END $$;

-- 2. Two-Phase Proposal Acceptance Function (Phase 1)
CREATE OR REPLACE FUNCTION public.connect_accept_proposal(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid;
  v_prop record;
  v_job record;
  v_milestone_id uuid;
  v_job_title text;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT * INTO v_prop
  FROM public.connect_proposals
  WHERE id = p_proposal_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROPOSAL_NOT_FOUND';
  END IF;

  IF v_prop.status NOT IN ('pending', 'shortlisted') THEN
    RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Proposal status is %', v_prop.status;
  END IF;

  IF v_prop.to_user_id IS NOT NULL AND v_prop.to_user_id <> v_caller_id THEN
    IF v_prop.job_id IS NOT NULL THEN
      SELECT * INTO v_job FROM public.connect_jobs WHERE id = v_prop.job_id;
      IF NOT FOUND OR (COALESCE(v_job.posted_by, '00000000-0000-0000-0000-000000000000'::uuid) <> v_caller_id 
                       AND COALESCE(v_job.claimed_by, '00000000-0000-0000-0000-000000000000'::uuid) <> v_caller_id) THEN
        RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Caller does not own this proposal or job';
      END IF;
    ELSE
      RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Caller is not the recipient';
    END IF;
  ELSIF v_prop.to_user_id IS NULL THEN
    IF v_prop.job_id IS NOT NULL THEN
      SELECT * INTO v_job FROM public.connect_jobs WHERE id = v_prop.job_id;
      IF NOT FOUND OR (COALESCE(v_job.posted_by, '00000000-0000-0000-0000-000000000000'::uuid) <> v_caller_id 
                       AND COALESCE(v_job.claimed_by, '00000000-0000-0000-0000-000000000000'::uuid) <> v_caller_id) THEN
        RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Caller does not own the job';
      END IF;
    ELSE
      RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Proposal has no recipient';
    END IF;
  END IF;

  IF v_prop.job_id IS NOT NULL THEN
    SELECT title INTO v_job_title FROM public.connect_jobs WHERE id = v_prop.job_id;
  END IF;

  UPDATE public.connect_proposals
  SET 
    status = 'accepted',
    to_user_id = COALESCE(to_user_id, v_caller_id),
    updated_at = now()
  WHERE id = p_proposal_id;

  SELECT id INTO v_milestone_id
  FROM public.connect_milestones
  WHERE proposal_id = p_proposal_id;

  IF v_milestone_id IS NULL THEN
    INSERT INTO public.connect_milestones (
      proposal_id,
      job_id,
      engagement_request_id,
      client_user_id,
      freelancer_user_id,
      title,
      amount,
      currency,
      status,
      notes,
      created_at,
      updated_at
    ) VALUES (
      p_proposal_id,
      v_prop.job_id,
      v_prop.request_id,
      v_caller_id,
      v_prop.from_user_id,
      COALESCE(v_job_title, 'Contract Kickoff Milestone'),
      GREATEST(COALESCE(v_prop.amount, 1), 1),
      COALESCE(v_prop.currency, 'USD'),
      'pending_funding',
      'Phase 1: Proposal accepted. Awaiting Phase 2 escrow funding checkout.',
      now(),
      now()
    )
    RETURNING id INTO v_milestone_id;
  END IF;

  INSERT INTO public.notifications (
    user_uid,
    from_uid,
    title,
    body,
    kind,
    is_read,
    created_at
  ) VALUES (
    v_prop.from_user_id,
    v_caller_id,
    'Proposal Accepted!',
    'Your proposal for "' || COALESCE(v_job_title, 'the role') || '" has been accepted. The client has been directed to fund escrow.',
    'proposal_accepted',
    false,
    now()
  );

  INSERT INTO public.clivora_events (event_type, payload)
  VALUES (
    'proposal_accepted',
    jsonb_build_object(
      'proposal_id', p_proposal_id,
      'client_id', v_caller_id,
      'freelancer_id', v_prop.from_user_id,
      'milestone_id', v_milestone_id,
      'amount', GREATEST(COALESCE(v_prop.amount, 1), 1)
    )
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.connect_accept_proposal(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.connect_accept_proposal(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.accept_proposal_and_create_milestone(
  p_proposal_id UUID,
  p_client_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_milestone_id uuid;
  v_prop record;
BEGIN
  PERFORM public.connect_accept_proposal(p_proposal_id);

  SELECT id INTO v_milestone_id
  FROM public.connect_milestones
  WHERE proposal_id = p_proposal_id;

  SELECT * INTO v_prop
  FROM public.connect_proposals
  WHERE id = p_proposal_id;

  RETURN jsonb_build_object(
    'success', true,
    'proposal_id', p_proposal_id,
    'milestone_id', v_milestone_id,
    'status', 'accepted',
    'milestone_status', 'pending_funding',
    'amount', v_prop.amount,
    'redirect_url', '/checkout/escrow?milestone=' || v_milestone_id
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.accept_proposal_and_create_milestone(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_proposal_and_create_milestone(UUID, UUID) TO service_role;

-- 3. Milestone Deliverable Lifecycle RPCs
CREATE OR REPLACE FUNCTION public.submit_milestone_deliverable(
  p_milestone_id uuid,
  p_notes text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid;
  v_ms record;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT * INTO v_ms FROM public.connect_milestones WHERE id = p_milestone_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MILESTONE_NOT_FOUND';
  END IF;

  IF v_ms.freelancer_user_id <> v_caller_id THEN
    RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Only assigned freelancer can submit work';
  END IF;

  IF v_ms.status <> 'funded' THEN
    RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Milestone must be funded before submission (current status: %)', v_ms.status;
  END IF;

  UPDATE public.connect_milestones
  SET
    status = 'submitted',
    submitted_at = now(),
    notes = CASE WHEN p_notes <> '' THEN notes || E'
[Submission notes]: ' || p_notes ELSE notes END,
    updated_at = now()
  WHERE id = p_milestone_id;

  INSERT INTO public.notifications (
    user_uid,
    from_uid,
    title,
    body,
    kind,
    is_read,
    created_at
  ) VALUES (
    v_ms.client_user_id,
    v_caller_id,
    'Deliverables Submitted for Review',
    'Work has been submitted for "' || v_ms.title || '". The 14-day deterministic review period has begun.',
    'milestone_submitted',
    false,
    now()
  );

  INSERT INTO public.clivora_events (event_type, payload)
  VALUES (
    'milestone_submitted',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'client_id', v_ms.client_user_id,
      'freelancer_id', v_caller_id,
      'amount', v_ms.amount
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'milestone_id', p_milestone_id,
    'status', 'submitted',
    'submitted_at', now()
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.submit_milestone_deliverable(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_milestone_deliverable(uuid, text) TO service_role;

CREATE OR REPLACE FUNCTION public.approve_and_release_milestone(
  p_milestone_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid;
  v_ms record;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT * INTO v_ms FROM public.connect_milestones WHERE id = p_milestone_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MILESTONE_NOT_FOUND';
  END IF;

  IF v_ms.client_user_id <> v_caller_id THEN
    RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Only the client can approve and release escrow';
  END IF;

  IF v_ms.status NOT IN ('funded', 'submitted') THEN
    RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Milestone status must be funded or submitted (current: %)', v_ms.status;
  END IF;

  UPDATE public.connect_milestones
  SET
    status = 'released',
    released_at = now(),
    updated_at = now()
  WHERE id = p_milestone_id;

  INSERT INTO public.notifications (
    user_uid,
    from_uid,
    title,
    body,
    kind,
    is_read,
    created_at
  ) VALUES (
    v_ms.freelancer_user_id,
    v_caller_id,
    'Escrow Released!',
    'Your client approved "' || v_ms.title || '". Escrow funds of $' || v_ms.amount || ' have been released.',
    'milestone_released',
    false,
    now()
  );

  INSERT INTO public.clivora_events (event_type, payload)
  VALUES (
    'milestone_released',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'client_id', v_caller_id,
      'freelancer_id', v_ms.freelancer_user_id,
      'amount', v_ms.amount,
      'release_type', 'client_approval'
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'milestone_id', p_milestone_id,
    'status', 'released',
    'released_at', now()
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.approve_and_release_milestone(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_and_release_milestone(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.dispute_milestone(
  p_milestone_id uuid,
  p_reason text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid;
  v_ms record;
  v_target_user_id uuid;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT * INTO v_ms FROM public.connect_milestones WHERE id = p_milestone_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MILESTONE_NOT_FOUND';
  END IF;

  IF v_ms.client_user_id <> v_caller_id AND v_ms.freelancer_user_id <> v_caller_id THEN
    RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Caller is not a party to this milestone';
  END IF;

  IF v_ms.status NOT IN ('funded', 'submitted') THEN
    RAISE EXCEPTION 'ACTION_NOT_ALLOWED: Can only dispute funded or submitted milestones (current: %)', v_ms.status;
  END IF;

  UPDATE public.connect_milestones
  SET
    status = 'disputed',
    disputed_at = now(),
    notes = notes || E'
[Dispute opened by ' || v_caller_id::text || ']: ' || p_reason,
    updated_at = now()
  WHERE id = p_milestone_id;

  v_target_user_id := CASE WHEN v_caller_id = v_ms.client_user_id THEN v_ms.freelancer_user_id ELSE v_ms.client_user_id END;

  INSERT INTO public.notifications (
    user_uid,
    from_uid,
    title,
    body,
    kind,
    is_read,
    created_at
  ) VALUES (
    v_target_user_id,
    v_caller_id,
    'Milestone Dispute Initiated',
    'A dispute has been opened for "' || v_ms.title || '". Escrow auto-release is paused pending resolution.',
    'milestone_disputed',
    false,
    now()
  );

  INSERT INTO public.clivora_events (event_type, payload)
  VALUES (
    'milestone_disputed',
    jsonb_build_object(
      'milestone_id', p_milestone_id,
      'disputed_by', v_caller_id,
      'reason', p_reason
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'milestone_id', p_milestone_id,
    'status', 'disputed'
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.dispute_milestone(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dispute_milestone(uuid, text) TO service_role;

-- 4. 14-Day Deterministic Auto-Release Processor
CREATE OR REPLACE FUNCTION public.process_milestone_auto_release()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ms record;
  v_released_count integer := 0;
BEGIN
  FOR v_ms IN
    SELECT *
    FROM public.connect_milestones
    WHERE status = 'submitted'
      AND submitted_at IS NOT NULL
      AND submitted_at < (now() - INTERVAL '14 days')
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.connect_milestones
    SET
      status = 'released',
      released_at = now(),
      auto_release_scheduled = true,
      updated_at = now()
    WHERE id = v_ms.id;

    INSERT INTO public.notifications (
      user_uid,
      from_uid,
      title,
      body,
      kind,
      is_read,
      created_at
    ) VALUES (
      v_ms.freelancer_user_id,
      v_ms.client_user_id,
      'Escrow Auto-Released (14-Day Guarantee)',
      '14-day review period elapsed for "' || v_ms.title || '". Escrow funds of $' || v_ms.amount || ' have been automatically released.',
      'milestone_auto_released',
      false,
      now()
    );

    INSERT INTO public.notifications (
      user_uid,
      from_uid,
      title,
      body,
      kind,
      is_read,
      created_at
    ) VALUES (
      v_ms.client_user_id,
      v_ms.freelancer_user_id,
      'Milestone Auto-Approved',
      'The 14-day review period for "' || v_ms.title || '" elapsed without dispute. Milestone completed and escrow released.',
      'milestone_auto_released',
      false,
      now()
    );

    INSERT INTO public.clivora_events (event_type, payload)
    VALUES (
      'milestone_auto_released',
      jsonb_build_object(
        'milestone_id', v_ms.id,
        'client_id', v_ms.client_user_id,
        'freelancer_id', v_ms.freelancer_user_id,
        'amount', v_ms.amount,
        'submitted_at', v_ms.submitted_at
      )
    );

    v_released_count := v_released_count + 1;
  END LOOP;

  FOR v_ms IN
    SELECT *
    FROM public.connect_milestones
    WHERE status = 'submitted'
      AND submitted_at IS NOT NULL
      AND submitted_at <= (now() - INTERVAL '10 days')
      AND submitted_at > (now() - INTERVAL '11 days')
  LOOP
    INSERT INTO public.notifications (
      user_uid,
      from_uid,
      title,
      body,
      kind,
      is_read,
      created_at
    ) VALUES (
      v_ms.client_user_id,
      v_ms.freelancer_user_id,
      '4 Days Remaining on Deliverable Review',
      'Reminder: You have 4 days to review "' || v_ms.title || '". Escrow funds will auto-release on Day 14 if no dispute is opened.',
      'milestone_review_reminder',
      false,
      now()
    );
  END LOOP;

  FOR v_ms IN
    SELECT *
    FROM public.connect_milestones
    WHERE status = 'submitted'
      AND submitted_at IS NOT NULL
      AND submitted_at <= (now() - INTERVAL '13 days')
      AND submitted_at > (now() - INTERVAL '13 days 12 hours')
  LOOP
    INSERT INTO public.notifications (
      user_uid,
      from_uid,
      title,
      body,
      kind,
      is_read,
      created_at
    ) VALUES (
      v_ms.client_user_id,
      v_ms.freelancer_user_id,
      'Final Notice: 24 Hours on Deliverable Review',
      'Action needed: 24 hours remain to review "' || v_ms.title || '". Escrow funds will auto-release tomorrow.',
      'milestone_final_notice',
      false,
      now()
    );
  END LOOP;

  RETURN v_released_count;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.process_milestone_auto_release() TO service_role;
GRANT EXECUTE ON FUNCTION public.process_milestone_auto_release() TO postgres;

-- 5. Auto-release pg_cron schedule
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'clivora-milestone-auto-release-daily') THEN
    PERFORM cron.unschedule('clivora-milestone-auto-release-daily');
  END IF;

  PERFORM cron.schedule(
    'clivora-milestone-auto-release-daily',
    '0 0 * * *',
    'SELECT public.process_milestone_auto_release();'
  );
END $$;

-- 6. Job Claim Proposal Auto-Linker
CREATE OR REPLACE FUNCTION public.connect_job_claim(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job record;
  v_user_id uuid;
  v_proposals_linked integer := 0;
begin
  if p_token is null or length(trim(p_token)) = 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid_token');
  end if;

  v_user_id := auth.uid();
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  select * into v_job from public.connect_jobs
  where claim_token = trim(p_token)
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid_or_claimed');
  end if;

  update public.profiles
  set account_type = 'client', role = 'client'
  where id = v_user_id;

  insert into public.connect_profiles (user_id, account_type, display_title, moderation_status, is_listed, is_verified)
  values (v_user_id, 'client', coalesce(v_job.company_name, 'Hiring Partner'), 'approved', true, true)
  on conflict (user_id) do update
  set account_type = 'client',
      moderation_status = 'approved',
      updated_at = now();

  update public.connect_jobs
  set claimed_by = v_user_id,
      posted_by = v_user_id,
      claim_token = null,
      updated_at = now()
  where id = v_job.id;

  update public.connect_proposals
  set to_user_id = v_user_id,
      updated_at = now()
  where job_id = v_job.id and (to_user_id is null or to_user_id = '00000000-0000-0000-0000-000000000000'::uuid);

  get diagnostics v_proposals_linked = row_count;

  if v_proposals_linked > 0 then
    insert into public.notifications (
      user_uid,
      from_uid,
      title,
      body,
      kind,
      is_read,
      created_at
    ) values (
      v_user_id,
      null,
      'Applicant Proposals Waiting',
      'You have ' || v_proposals_linked || ' candidate proposal(s) waiting for review on your claimed listing "' || v_job.title || '".',
      'job_claimed_proposals_ready',
      false,
      now()
    );
  end if;

  insert into public.clivora_events (event_type, payload)
  values (
    'job_claimed',
    jsonb_build_object(
      'job_id', v_job.id,
      'client_id', v_user_id,
      'proposals_linked', v_proposals_linked
    )
  );

  return jsonb_build_object(
    'ok', true,
    'job_id', v_job.id,
    'title', v_job.title,
    'proposals_linked', v_proposals_linked
  );
end;
$function$;

GRANT EXECUTE ON FUNCTION public.connect_job_claim(text) TO authenticated;
