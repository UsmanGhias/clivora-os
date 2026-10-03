-- CLIVORA Phase 0 foundations (additive, idempotent).
-- Exported from live Supabase (phase0_foundations_smemaster_program).
-- See docs/internal/PHASE0_FOUNDATIONS.md

begin;

-- ---------------------------------------------------------------------------
-- Idempotency keys
-- ---------------------------------------------------------------------------
create table if not exists public.idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  scope text not null,
  key text not null,
  request_hash text,
  response jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (owner_uid, scope, key)
);

-- ---------------------------------------------------------------------------
-- Audit events + write_audit_event()
-- ---------------------------------------------------------------------------
create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_uid uuid references auth.users(id) on delete set null,
  workspace_uid uuid,
  action text not null,
  entity_type text not null,
  entity_id text,
  payload jsonb not null default '{}'::jsonb,
  ip inet,
  user_agent text,
  created_at timestamptz not null default now()
);
create index if not exists audit_events_actor_idx on public.audit_events (actor_uid, created_at desc);
create index if not exists audit_events_workspace_idx on public.audit_events (workspace_uid, created_at desc);

create or replace function public.write_audit_event(
  p_action text,
  p_entity_type text,
  p_entity_id text default null,
  p_workspace_uid uuid default null,
  p_payload jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_id uuid;
begin
  insert into public.audit_events(actor_uid, workspace_uid, action, entity_type, entity_id, payload)
  values (auth.uid(), coalesce(p_workspace_uid, auth.uid()), p_action, p_entity_type, p_entity_id, coalesce(p_payload, '{}'::jsonb))
  returning id into v_id;
  return v_id;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Vault tables (flag vault_cloud remains OFF until admin enablement)
-- ---------------------------------------------------------------------------
create table if not exists public.vault_attachments (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  entity_type text not null default 'file',
  entity_id text,
  storage_bucket text not null default 'project-files',
  storage_path text not null,
  file_name text not null default '',
  mime_type text,
  size_bytes bigint not null default 0,
  checksum text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists vault_attachments_owner_idx on public.vault_attachments (owner_uid, created_at desc);

create table if not exists public.vault_share_links (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  storage_path text,
  file_path text,
  file_id text,
  file_name text not null default '',
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  expires_at timestamptz not null,
  max_downloads integer,
  download_count integer not null default 0,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Money dual-write (additive minor-unit columns; numeric stays source until cutover)
-- ---------------------------------------------------------------------------
alter table public.crm_invoices
  add column if not exists subtotal_minor bigint,
  add column if not exists tax_minor bigint,
  add column if not exists discount_minor bigint,
  add column if not exists total_minor bigint,
  add column if not exists amount_paid_minor bigint;

alter table public.invoice_shares
  add column if not exists total_minor bigint;

alter table public.quote_shares
  add column if not exists total_minor bigint,
  add column if not exists subtotal_minor bigint;

-- ---------------------------------------------------------------------------
-- Automation webhook queue: job states + idempotency columns
-- (table created in 20260711_phase2_connect_trust.sql)
-- ---------------------------------------------------------------------------
alter table public.automation_webhook_queue
  add column if not exists next_attempt_at timestamptz,
  add column if not exists permanently_failed_at timestamptz,
  add column if not exists idempotency_key text,
  add column if not exists owner_uid uuid references auth.users(id) on delete set null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'automation_webhook_queue_status_chk'
  ) then
    alter table public.automation_webhook_queue
      add constraint automation_webhook_queue_status_chk
      check (status = any (array[
        'pending'::text, 'processing'::text, 'succeeded'::text,
        'failed'::text, 'permanently_failed'::text, 'retrying'::text
      ]));
  end if;
end $$;

create unique index if not exists automation_webhook_queue_idem_uidx
  on public.automation_webhook_queue (idempotency_key)
  where (idempotency_key is not null);

-- ---------------------------------------------------------------------------
-- quote_shares RLS (mirrors invoice_shares party access)
-- ---------------------------------------------------------------------------
alter table public.quote_shares enable row level security;

drop policy if exists quote_shares_select on public.quote_shares;
create policy quote_shares_select on public.quote_shares
  for select to authenticated
  using (
    is_admin()
    or freelancer_uid = auth.uid()
    or client_uid = auth.uid()
    or lower(client_email) = lower(coalesce(my_email(), ''::text))
  );

drop policy if exists quote_shares_write on public.quote_shares;
create policy quote_shares_write on public.quote_shares
  for all to authenticated
  using (is_admin() or freelancer_uid = auth.uid())
  with check (is_admin() or freelancer_uid = auth.uid());

drop policy if exists quote_shares_client_update on public.quote_shares;
create policy quote_shares_client_update on public.quote_shares
  for update to authenticated
  using (
    is_admin()
    or client_uid = auth.uid()
    or lower(client_email) = lower(coalesce(my_email(), ''::text))
  )
  with check (
    is_admin()
    or client_uid = auth.uid()
    or lower(client_email) = lower(coalesce(my_email(), ''::text))
  );

-- ---------------------------------------------------------------------------
-- RLS: idempotency_keys, audit_events, vault tables
-- ---------------------------------------------------------------------------
alter table public.idempotency_keys enable row level security;
alter table public.audit_events enable row level security;
alter table public.vault_attachments enable row level security;
alter table public.vault_share_links enable row level security;

drop policy if exists idempotency_keys_owner on public.idempotency_keys;
create policy idempotency_keys_owner on public.idempotency_keys
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists audit_events_admin_select on public.audit_events;
create policy audit_events_admin_select on public.audit_events
  for select to authenticated
  using (is_admin() or actor_uid = auth.uid() or workspace_uid = auth.uid());

drop policy if exists vault_attachments_owner on public.vault_attachments;
create policy vault_attachments_owner on public.vault_attachments
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists vault_share_owner on public.vault_share_links;
create policy vault_share_owner on public.vault_share_links
  for all to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

-- ---------------------------------------------------------------------------
-- Feature-flag key registration (enablement NOT set here — see flag-truth.md)
-- ---------------------------------------------------------------------------
insert into public.app_feature_flags (key, enabled) values
  ('phase0_foundations', false),
  ('money_minor_units_dual_write', false),
  ('vault_cloud', false)
on conflict (key) do nothing;

commit;
