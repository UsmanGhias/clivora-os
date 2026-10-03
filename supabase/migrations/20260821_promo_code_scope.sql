-- Scope promo code reads to the presented code, and make max_uses real.
--
-- TWO BUGS, both the same shape as the invoice_shares and vault_share_links
-- findings in this sprint.
--
-- 1. DISCOUNT ENUMERATION
--    promo_codes_public_read was `for select to anon, authenticated using
--    (is_active and (expires_at is null or expires_at > now()))`. The row filter
--    describes which codes are live, not which code the caller asked about, so
--    any holder of the anon key could list every live discount code with its
--    type and value and then use them. Same root cause as the invoice guest
--    link: the secret the caller presents (here, the typed code) is invisible to
--    RLS, so the policy was widened until it worked.
--
--    The server path does not need this policy at all -- validatePromoCode runs
--    with the service role key -- but it falls back to the caller's session when
--    SUPABASE_SERVICE_ROLE_KEY is unset, which is why the policy existed. A
--    SECURITY DEFINER lookup keyed on the presented code serves both paths
--    without exposing the table.
--
-- 2. max_uses WAS A DEAD CONTROL
--    The checkout page incremented used_count from the browser:
--
--        select used_count ... ; update promo_codes set used_count = n + 1
--
--    promo_codes has no UPDATE policy for anon or authenticated, so that write
--    always failed, and the failure was swallowed by an empty catch. Every code
--    in the table shows used_count = 0 while having a cap set. Even with a
--    policy it would have been wrong: read-then-write is not atomic, and a
--    browser can simply skip the call.
--
--    promo_code_redeem does the cap check and the increment in one statement, so
--    the cap holds under concurrency and cannot be bypassed by not calling it
--    (the caller gets no discount recorded if it does not).

begin;

drop policy if exists promo_codes_public_read on public.promo_codes;

create or replace function public.promo_code_lookup(p_code text)
returns table (
  code text,
  discount_type text,
  discount_value numeric,
  applies_to text,
  max_uses integer,
  used_count integer,
  expires_at timestamptz,
  is_active boolean
)
language sql
stable
security definer
set search_path = 'public'
as $fn$
  select p.code, p.discount_type, p.discount_value, p.applies_to,
         p.max_uses, p.used_count, p.expires_at, p.is_active
  from public.promo_codes p
  where upper(p.code) = upper(btrim(p_code))
  limit 1;
$fn$;

comment on function public.promo_code_lookup(text) is
  'Validate a single presented promo code. Replaces promo_codes_public_read, which let any anon caller enumerate every live discount.';

create or replace function public.promo_code_redeem(p_code text)
returns integer
language sql
volatile
security definer
set search_path = 'public'
as $fn$
  update public.promo_codes p
     set used_count = coalesce(p.used_count, 0) + 1
   where upper(p.code) = upper(btrim(p_code))
     and coalesce(p.is_active, false)
     and (p.expires_at is null or p.expires_at > now())
     and (p.max_uses is null or coalesce(p.used_count, 0) < p.max_uses)
  returning p.used_count;
$fn$;

comment on function public.promo_code_redeem(text) is
  'Atomically spend one use of a promo code. Returns the new used_count, or no row if the code is unknown, inactive, expired or at its cap.';

revoke all on function public.promo_code_lookup(text) from public;
revoke all on function public.promo_code_redeem(text) from public;
grant execute on function public.promo_code_lookup(text) to anon, authenticated;
grant execute on function public.promo_code_redeem(text) to anon, authenticated;

commit;
