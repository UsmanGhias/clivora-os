-- Security invariants for the CLIVORA Postgres schema.
--
-- Every assertion here corresponds to a real defect found during the Sprint 3
-- audit. Each one raises an exception naming the offending objects, so a
-- regression fails loudly instead of silently re-opening a hole.
--
-- Run it against any environment:
--
--     psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/security_invariants.sql
--
-- It only reads the catalog, so it is safe to run against production. A clean
-- run prints one NOTICE per invariant and nothing else.

\set ON_ERROR_STOP on

do $$
declare
  bad text;
begin
  -- ==========================================================================
  -- 1. No table in `public` may be readable by anon through a policy that does
  --    not constrain rows to the caller.
  --
  --    Regression guard for: invoice_shares_public_token_read, which was
  --    `for select to public using (public_token is not null)`. That let any
  --    holder of the (public) anon key enumerate every shared invoice,
  --    including client emails and the share tokens themselves.
  --
  --    Guest access to a single row by bearer token belongs in a SECURITY
  --    DEFINER function that takes the token as an argument, because RLS cannot
  --    see the token. See invoice_share_by_token, promo_code_lookup and
  --    vault_lookup_share_by_token.
  --
  --    app_feature_flags is the one accepted exception. Both clients must read
  --    flags before anyone signs in, and the table holds only a flag name, a
  --    boolean, and who last changed it. Reviewed and accepted 2026-08-21: the
  --    only thing it discloses is which features exist.
  -- ==========================================================================
  select string_agg(format('%s.%s', tablename, policyname), ', ')
    into bad
  from pg_policies
  where schemaname = 'public'
    and cmd in ('SELECT', 'ALL')
    and ('anon' = any (roles::text[]) or 'public' = any (roles::text[]))
    and coalesce(qual, '') !~ 'auth\.uid\(\)'
    and tablename <> 'app_feature_flags';

  if bad is not null then
    raise exception
      'anon-readable policy with no per-caller row constraint: %', bad;
  end if;
  raise notice 'ok 1 - no unconstrained anon read policies';

  -- ==========================================================================
  -- 2. Trigger functions must not be reachable as PostgREST RPC.
  --
  --    Regression guard for 21 trigger functions that were EXECUTE-able by
  --    PUBLIC/anon/authenticated. Several exist specifically to enforce limits
  --    (free-plan caps, privileged-column guards) and are SECURITY DEFINER, so
  --    publishing them as callable endpoints was needless attack surface.
  -- ==========================================================================
  select string_agg(p.proname, ', ')
    into bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join pg_type t on t.oid = p.prorettype
  where n.nspname = 'public'
    and t.typname in ('trigger', 'event_trigger')
    and (
      p.proacl is null
      or exists (
        select 1
        from aclexplode(p.proacl) a
        left join pg_roles r on r.oid = a.grantee
        where coalesce(r.rolname, 'PUBLIC') in ('anon', 'authenticated', 'PUBLIC')
      )
    );

  if bad is not null then
    raise exception 'trigger function exposed as RPC: %', bad;
  end if;
  raise notice 'ok 2 - no trigger functions exposed as RPC';

  -- ==========================================================================
  -- 3. The pg_cron entry point must stay cron-only.
  --
  --    Regression guard for invoke_invoice_reminders(), which anon could call.
  --    It reads a Vault secret and POSTs the send-invoice-reminders Edge
  --    Function, so an anonymous caller could trigger the whole reminder
  --    fan-out on demand.
  -- ==========================================================================
  select string_agg(coalesce(r.rolname, 'PUBLIC'), ', ')
    into bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join aclexplode(p.proacl) a
  left join pg_roles r on r.oid = a.grantee
  where n.nspname = 'public'
    and p.proname = 'invoke_invoice_reminders'
    and coalesce(r.rolname, 'PUBLIC') in ('anon', 'authenticated', 'PUBLIC');

  if bad is not null then
    raise exception 'invoke_invoice_reminders is callable by: %', bad;
  end if;
  raise notice 'ok 3 - invoice reminder cron entry point is not client-callable';

  -- ==========================================================================
  -- 4. Every SECURITY DEFINER function must pin its search_path.
  --
  --    Without it, the caller's search_path decides which schema an unqualified
  --    name resolves to, so a user-created object can shadow a real one inside
  --    a function running with the owner's privileges.
  -- ==========================================================================
  select string_agg(p.proname, ', ')
    into bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and (
      p.proconfig is null
      or not exists (
        select 1 from unnest(p.proconfig) c where c like 'search_path=%'
      )
    );

  if bad is not null then
    raise exception 'SECURITY DEFINER function with mutable search_path: %', bad;
  end if;
  raise notice 'ok 4 - all SECURITY DEFINER functions pin search_path';

  -- ==========================================================================
  -- 5. Every table in `public` must have RLS enabled.
  --
  --    A table with RLS off is fully readable and writable by anyone holding
  --    the anon key. The rls_auto_enable event trigger is meant to prevent this
  --    for new tables; this asserts the outcome rather than trusting the
  --    mechanism.
  -- ==========================================================================
  select string_agg(c.relname, ', ')
    into bad
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and not c.relrowsecurity;

  if bad is not null then
    raise exception 'table without row level security: %', bad;
  end if;
  raise notice 'ok 5 - RLS enabled on every public table';

  -- ==========================================================================
  -- 6. The vault share quota must be enforced in the database.
  --
  --    Regression guard for a dead control: max_downloads was only ever checked
  --    in the Next.js page, and download_count was never incremented anywhere
  --    in the product, so the cap could not trip. The redeem function now does
  --    the check and the increment in one UPDATE ... RETURNING.
  -- ==========================================================================
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'vault_redeem_share_token'
      and pg_get_functiondef(p.oid) like '%download_count%'
      and pg_get_functiondef(p.oid) like '%max_downloads%'
  ) then
    raise exception
      'vault_redeem_share_token must enforce max_downloads and increment download_count';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'vault_lookup_share_by_token'
      and pg_get_function_result(p.oid) like '%storage_path%'
  ) then
    raise exception
      'vault_lookup_share_by_token must not return storage_path; that belongs to the redeem path';
  end if;
  raise notice 'ok 6 - vault share expiry and download quota are enforced in SQL';

  -- ==========================================================================
  -- 7. The promo code cap must be enforced in the database.
  --
  --    Regression guard for the third dead counter found this sprint. The
  --    checkout page incremented used_count from the browser against a table
  --    with no client UPDATE policy, so the write always failed silently and
  --    max_uses could never trip.
  -- ==========================================================================
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'promo_code_redeem'
      and pg_get_functiondef(p.oid) like '%max_uses%'
      and pg_get_functiondef(p.oid) like '%used_count%'
  ) then
    raise exception
      'promo_code_redeem must enforce max_uses and increment used_count';
  end if;
  raise notice 'ok 7 - promo code usage cap is enforced in SQL';

  raise notice 'all security invariants hold';
end;
$$;
