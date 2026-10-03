-- Phase 1: account deletion RPC + Connect accept hardening
-- Additive only. Safe to apply on live Clivora.

-- ---------------------------------------------------------------------------
-- Account deletion request (AUTH-06)
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists deletion_requested_at timestamptz,
  add column if not exists deletion_status text;

comment on column public.profiles.deletion_requested_at is
  'When the user requested account deletion. Access should be treated as revoked after this is set.';
comment on column public.profiles.deletion_status is
  'requested | processing | anonymized | cancelled';

create or replace function public.request_account_deletion()
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  update public.profiles
  set
    deletion_requested_at = coalesce(deletion_requested_at, now()),
    deletion_status = coalesce(nullif(deletion_status, ''), 'requested'),
    is_restricted = true,
    block_reason = coalesce(block_reason, 'Account deletion requested'),
    updated_at = now()
  where id = auth.uid();

  -- Best-effort: revoke refresh tokens for this user (Supabase auth schema).
  begin
    delete from auth.sessions where user_id = auth.uid();
    delete from auth.refresh_tokens where user_id = auth.uid();
  exception
    when others then
      null;
  end;
end;
$$;

revoke all on function public.request_account_deletion() from public;
grant execute on function public.request_account_deletion() to authenticated;

-- ---------------------------------------------------------------------------
-- Connect accept: only recipient via SECURITY DEFINER RPC (MATCH / SEC-04)
-- Drop broad UPDATE that allowed from_user_id to mutate status.
-- ---------------------------------------------------------------------------
drop policy if exists connect_requests_update on public.connect_requests;
drop policy if exists connect_requests_update_admin on public.connect_requests;

create policy connect_requests_update_admin
  on public.connect_requests
  for update
  to authenticated
  using (is_admin())
  with check (is_admin());

create or replace function public.connect_respond_request(p_request_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_req public.connect_requests;
  v_restricted boolean;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select coalesce(is_restricted, false)
      or deletion_requested_at is not null
    into v_restricted
  from public.profiles
  where id = auth.uid();

  if coalesce(v_restricted, false) then
    raise exception 'ACCOUNT_RESTRICTED';
  end if;

  select * into v_req
  from public.connect_requests
  where id = p_request_id
  for update;

  if not found or v_req.to_user_id <> auth.uid() or v_req.status <> 'pending' then
    raise exception 'ACTION_NOT_ALLOWED';
  end if;

  if p_accept then
    update public.connect_requests
      set status = 'accepted',
          revealed_at = now(),
          updated_at = now()
      where id = p_request_id;
  else
    update public.connect_requests
      set status = 'declined',
          updated_at = now()
      where id = p_request_id;
  end if;
end;
$$;

revoke all on function public.connect_respond_request(uuid, boolean) from public;
grant execute on function public.connect_respond_request(uuid, boolean) to authenticated;
