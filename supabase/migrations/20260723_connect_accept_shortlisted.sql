-- Allow clients to hire shortlisted Connect proposals.
-- The RPC remains recipient-only and does not expose direct table updates.

drop function if exists public.connect_accept_proposal(uuid);

create or replace function public.connect_accept_proposal(p_proposal_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.connect_proposals
     set status = 'accepted',
         updated_at = now()
   where id = p_proposal_id
     and to_user_id = auth.uid()
     and status in ('pending', 'shortlisted');

  if not found then
    raise exception 'ACTION_NOT_ALLOWED';
  end if;
end;
$$;

grant execute on function public.connect_accept_proposal(uuid) to authenticated;
