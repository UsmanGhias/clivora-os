-- Migration: 20261119_connect_transition_milestone_hardening.sql
-- Harden connect_transition_milestone to prevent unauthorized escrow funding or release

CREATE OR REPLACE FUNCTION public.connect_transition_milestone(p_milestone_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
declare
  v_m public.connect_milestones;
begin
  if p_status not in ('pending', 'funded', 'released', 'disputed', 'cancelled') then
    raise exception 'ACTION_NOT_ALLOWED: Invalid status';
  end if;
  select * into v_m from public.connect_milestones where id = p_milestone_id for update;
  if not found or (v_m.client_user_id <> auth.uid() and v_m.freelancer_user_id <> auth.uid() and not public.is_admin()) then
    raise exception 'ACTION_NOT_ALLOWED: Unauthorized for milestone';
  end if;
  -- Only client or admin can fund escrow or release escrow
  if p_status in ('funded', 'released') and auth.uid() <> v_m.client_user_id and not public.is_admin() then
    raise exception 'ACTION_NOT_ALLOWED: Only hiring client or admin may fund or release escrow';
  end if;
  -- Only client (if still pending) or admin can cancel
  if p_status = 'cancelled' and (auth.uid() <> v_m.client_user_id or v_m.status <> 'pending') and not public.is_admin() then
    raise exception 'ACTION_NOT_ALLOWED: Cannot cancel funded/active milestone';
  end if;

  update public.connect_milestones set
    status = p_status,
    updated_at = now(),
    released_at = case when p_status = 'released' then now() else released_at end,
    disputed_at = case when p_status = 'disputed' then now() else disputed_at end
  where id = p_milestone_id;
end;
$$;

REVOKE EXECUTE ON FUNCTION public.connect_transition_milestone(uuid, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.connect_transition_milestone(uuid, text) TO authenticated, service_role;
