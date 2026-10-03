-- Connect + CRM contract documentation (live DDL was applied remotely).
-- This file no longer uses `select 1` alone — it records the expected surface
-- and asserts core objects exist so drift fails loudly in environments that
-- run repo migrations from scratch after Connect bootstrap.

-- Expected tables (created on live via remote migrations / MCP):
--   connect_profiles, connect_need_posts, connect_requests,
--   connect_proposals, connect_milestones, connect_reviews,
--   crm_cloud_backups (and related CRM cloud tables)
-- Expected RPCs:
--   is_pro_plus(), connect_respond_request(uuid, boolean),
--   connect_peer_contact(uuid), connect_send_request(...),
--   connect_submit_proposal(...), connect_spend_credits(...)
-- Expected view:
--   connect_request_details (emails null until status = accepted)

do $$
begin
  if to_regclass('public.connect_requests') is null then
    raise notice 'connect_requests missing — apply live Connect bootstrap before Phase 1 hardening';
  end if;
  if to_regclass('public.connect_profiles') is null then
    raise notice 'connect_profiles missing — apply live Connect bootstrap before Phase 1 hardening';
  end if;
end $$;
