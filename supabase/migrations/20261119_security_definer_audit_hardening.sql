-- Migration: 20261119_security_definer_audit_hardening.sql
-- Cloudflare Security Audit Remediation:
-- 1. Revoke public/anon/authenticated execution on invoke_send_clivora_email
-- 2. Revoke anon/authenticated execution on promo_code_redeem
-- 3. Harden connect_submit_proposal with explicit positive amount constraint check

-- Revoke public execution on invoke_send_clivora_email
REVOKE ALL ON FUNCTION public.invoke_send_clivora_email(text, text, text, text, text, text, numeric, integer, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.invoke_send_clivora_email(text, text, text, text, text, text, numeric, integer, text, text) TO postgres, service_role;

-- Revoke public execution on promo_code_redeem (only trusted backend with rate limits may spend uses)
REVOKE ALL ON FUNCTION public.promo_code_redeem(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.promo_code_redeem(text) TO postgres, service_role;

-- Harden connect_submit_proposal to strictly validate positive amount
CREATE OR REPLACE FUNCTION public.connect_submit_proposal(
  p_to_user_id uuid,
  p_need_id uuid,
  p_amount numeric,
  p_currency text,
  p_timeline_days integer,
  p_message text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_id uuid := gen_random_uuid();
begin
  perform public.connect_require_pro_plus();
  if p_to_user_id is null or p_to_user_id = auth.uid() then
    raise exception 'ACTION_NOT_ALLOWED';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'INVALID_AMOUNT: Proposal amount must be greater than 0';
  end if;
  perform public.connect_spend_credits('proposal', 'connect_proposal', v_id, 'proposal:' || v_id::text);
  insert into public.connect_proposals
    (id, from_user_id, to_user_id, need_id, amount, currency, timeline_days, message, status)
  values
    (v_id, auth.uid(), p_to_user_id, p_need_id, p_amount, coalesce(nullif(p_currency, ''), 'USD'),
     p_timeline_days, coalesce(p_message, ''), 'pending');
  return v_id;
end;
$$;
