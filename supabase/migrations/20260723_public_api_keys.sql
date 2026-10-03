-- Public Integrations API keys.
-- Raw tokens are shown once by the admin UI. API requests validate via service role
-- against key_hash; clients should never be granted access to key_hash.

create table if not exists public.api_keys (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  name text not null,
  key_prefix text not null,
  key_hash text not null unique,
  scopes text[] not null default '{}'::text[],
  last_used_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint api_keys_name_nonempty check (length(trim(name)) > 0),
  constraint api_keys_prefix_nonempty check (length(trim(key_prefix)) > 0),
  constraint api_keys_hash_nonempty check (length(trim(key_hash)) > 0)
);

create index if not exists api_keys_owner_created_idx
  on public.api_keys (owner_uid, created_at desc);

create index if not exists api_keys_active_hash_idx
  on public.api_keys (key_hash)
  where revoked_at is null;

create index if not exists api_keys_scopes_gin_idx
  on public.api_keys using gin (scopes);

alter table public.api_keys enable row level security;

drop policy if exists api_keys_owner_select on public.api_keys;
create policy api_keys_owner_select on public.api_keys
  for select to authenticated
  using (owner_uid = auth.uid());

-- Admin/server routes use the service role for insert/revoke/validation. Keep
-- browser grants read-only and omit key_hash from column-level SELECT grants.
revoke all on public.api_keys from anon, authenticated;
grant all on public.api_keys to service_role;
grant select (
  id,
  owner_uid,
  name,
  key_prefix,
  scopes,
  last_used_at,
  expires_at,
  revoked_at,
  created_at
) on public.api_keys to authenticated;

comment on table public.api_keys is 'Hash-only API tokens for CLIVORA Public Integrations API v1.';
comment on column public.api_keys.key_hash is 'SHA-256 hash of the raw bearer token. Service-role access only.';
