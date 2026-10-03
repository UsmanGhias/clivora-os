-- Phase A–F foundation: device tokens, chat blocks, public invoice tokens, feature flags, automation log
-- Applied remotely via MCP; kept in repo for local/CI parity.

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_uid uuid not null references public.profiles (id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  updated_at timestamptz not null default now(),
  unique (user_uid, token)
);
alter table public.device_tokens enable row level security;

create table if not exists public.chat_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_uid uuid not null references public.profiles (id) on delete cascade,
  blocked_uid uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (blocker_uid, blocked_uid)
);
alter table public.chat_blocks enable row level security;

alter table public.invoice_shares
  add column if not exists public_token text,
  add column if not exists payment_reference text,
  add column if not exists payment_receipt_path text,
  add column if not exists freelancer_confirmed boolean not null default false,
  add column if not exists freelancer_confirmed_at timestamptz;

create table if not exists public.app_feature_flags (
  key text primary key,
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id)
);

create table if not exists public.automation_run_log (
  id uuid primary key default gen_random_uuid(),
  user_uid uuid not null references public.profiles (id) on delete cascade,
  automation_key text not null,
  detail text not null default '',
  created_at timestamptz not null default now()
);
