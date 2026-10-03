-- Client quote shares (mirror invoice_shares). Apply in Supabase SQL editor if missing.
create table if not exists public.quote_shares (
  share_id text primary key,
  freelancer_uid uuid not null,
  freelancer_email text,
  client_email text not null,
  client_uid uuid,
  local_quote_id bigint not null,
  quote_number text not null,
  status text not null default 'sent',
  subtotal double precision default 0,
  tax_rate double precision default 0,
  discount double precision default 0,
  total double precision default 0,
  currency text default 'USD',
  line_items text default '[]',
  issue_date timestamptz,
  valid_until timestamptz,
  updated_at timestamptz default now()
);
create index if not exists quote_shares_client_email_idx on public.quote_shares (client_email);
create index if not exists quote_shares_client_uid_idx on public.quote_shares (client_uid);
