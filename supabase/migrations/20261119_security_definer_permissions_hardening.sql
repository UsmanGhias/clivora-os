-- Security Hardening: Revoke anonymous & untrusted execution from SECURITY DEFINER functions

-- 1. Revoke batch internal crawlers/workers from anon and authenticated
REVOKE EXECUTE ON FUNCTION public.ingest_github_oss_jobs_batch(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ingest_github_oss_jobs_batch(jsonb) TO postgres, service_role;

REVOKE EXECUTE ON FUNCTION public.invoke_sync_external_jobs() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.invoke_sync_external_jobs() TO postgres, service_role;

REVOKE EXECUTE ON FUNCTION public.process_outreach_clients_batch(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_outreach_clients_batch(integer) TO postgres, service_role;

REVOKE EXECUTE ON FUNCTION public.process_outreach_freelancers_batch(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_outreach_freelancers_batch(integer) TO postgres, service_role;

-- 2. Revoke sensitive marketplace & milestone actions from anon
REVOKE EXECUTE ON FUNCTION public.accept_proposal_and_create_milestone(uuid, uuid) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_proposal_and_create_milestone(uuid, uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.connect_accept_proposal(uuid) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.connect_accept_proposal(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.connect_transition_milestone(uuid, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.connect_transition_milestone(uuid, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.submit_milestone_deliverable(uuid, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_milestone_deliverable(uuid, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.approve_and_release_milestone(uuid) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.approve_and_release_milestone(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.dispute_milestone(uuid, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.dispute_milestone(uuid, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.connect_submit_proposal(uuid, uuid, numeric, text, integer, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.connect_submit_proposal(uuid, uuid, numeric, text, integer, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.connect_spend_credits(text, text, uuid, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.connect_spend_credits(text, text, uuid, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.connect_publish_need(text, text, text[], text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.connect_publish_need(text, text, text[], text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.connect_publish_profile(text, text, text[], numeric) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.connect_publish_profile(text, text, text[], numeric) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.admin_dashboard_summary() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_summary() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.client_home_summary() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.client_home_summary() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.freelancer_home_summary() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.freelancer_home_summary() TO authenticated, service_role;
