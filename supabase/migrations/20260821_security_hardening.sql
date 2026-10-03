-- Security hardening pass (Sprint 3 audit).
--
-- Findings this migration closes, in order of severity:
--
--   1. public.invoke_invoice_reminders() was EXECUTE-able by `anon`. It reads a
--      cron secret out of Vault and POSTs the send-invoice-reminders Edge
--      Function. Any unauthenticated caller could therefore trigger the whole
--      reminder fan-out on demand. It is only ever invoked by pg_cron (which
--      runs as postgres), so no client role needs it.
--
--   2. 21 trigger-only functions were EXECUTE-able by PUBLIC/anon/authenticated,
--      which also publishes them as PostgREST RPC endpoints. A trigger function
--      called outside a trigger context cannot do useful work, but several are
--      SECURITY DEFINER and exist specifically to *enforce* limits (free-plan
--      caps, privileged-column guards), so leaving them reachable is needless
--      attack surface.
--
--   3. Three trigger functions had a role-mutable search_path.
--
--   4. vault_share_links.max_downloads was a dead control: nothing in the
--      product ever incremented download_count, and expiry/cap were only
--      checked in the Next.js page, never in the database. An expired token
--      still returned its storage_path over the anon key.

begin;

-- ---------------------------------------------------------------------------
-- 1. Cron-only entry point
-- ---------------------------------------------------------------------------

revoke execute on function public.invoke_invoice_reminders() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Trigger functions are not RPC endpoints
-- ---------------------------------------------------------------------------
-- Revoking from PUBLIC as well as the two client roles is what actually removes
-- them from the PostgREST schema cache; anon/authenticated inherit PUBLIC.

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure::text as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_type t on t.oid = p.prorettype
    where n.nspname = 'public'
      and t.typname in ('trigger', 'event_trigger')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn.sig);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Pin search_path on the remaining mutable trigger functions
-- ---------------------------------------------------------------------------

alter function public.crm_reject_stale_update() set search_path = 'public';
alter function public.crm_invoice_payment_status() set search_path = 'public';
alter function public.invoice_shares_sync_total_minor() set search_path = 'public';

-- ---------------------------------------------------------------------------
-- 4. Vault share links: enforce expiry and the download cap in the database
-- ---------------------------------------------------------------------------
-- Split the old single function into a read path and a redeem path:
--
--   vault_lookup_share_by_token  -> metadata only, never the storage path, and
--                                   returns zero rows for a dead link so the
--                                   endpoint cannot be used to confirm that a
--                                   token exists.
--   vault_redeem_share_token     -> single atomic UPDATE ... RETURNING. The cap
--                                   is re-checked in the WHERE clause under the
--                                   row lock, so concurrent redeems cannot
--                                   overshoot max_downloads.

drop function if exists public.vault_lookup_share_by_token(text);

create function public.vault_lookup_share_by_token(p_token text)
returns table (
  id uuid,
  file_name text,
  expires_at timestamptz,
  max_downloads integer,
  download_count integer
)
language sql
stable
security definer
set search_path = 'public'
as $$
  select v.id, v.file_name, v.expires_at, v.max_downloads, v.download_count
  from public.vault_share_links v
  where v.token = p_token
    and (v.expires_at is null or v.expires_at > now())
    and (coalesce(v.max_downloads, 0) = 0 or v.download_count < v.max_downloads)
  limit 1;
$$;

create or replace function public.vault_redeem_share_token(p_token text)
returns table (
  file_name text,
  storage_path text
)
language sql
volatile
security definer
set search_path = 'public'
as $$
  update public.vault_share_links v
     set download_count = v.download_count + 1
   where v.token = p_token
     and (v.expires_at is null or v.expires_at > now())
     and (coalesce(v.max_downloads, 0) = 0 or v.download_count < v.max_downloads)
  returning v.file_name, v.storage_path;
$$;

revoke all on function public.vault_lookup_share_by_token(text) from public;
revoke all on function public.vault_redeem_share_token(text) from public;
grant execute on function public.vault_lookup_share_by_token(text) to anon, authenticated;
grant execute on function public.vault_redeem_share_token(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Document the two intentionally policy-less tables
-- ---------------------------------------------------------------------------
-- The security advisor reports these as "RLS enabled, no policies". That is the
-- intended state: deny-all to every client role, reachable only through the
-- SECURITY DEFINER accessors, which check for an unblocked admin profile first.

comment on table public.admin_integration_secrets is
  'Deny-all by design: RLS is enabled with no policies. Reach it only via admin_get_integration_secret/admin_upsert_integration_secret, which verify an unblocked admin profile.';

comment on table public._internal_secrets is
  'Deny-all by design: RLS is enabled with no policies. Server-side/service-role access only.';

commit;
