-- CLIVORA v2.3.2 — shared invoices + client payment confirmation
-- Run after 004_fix_google_auth_profile.sql

create table if not exists public.invoice_shares (
  share_id text primary key,
  freelancer_uid uuid not null references public.profiles (id) on delete cascade,
  freelancer_email text not null default '',
  client_email text not null,
  client_uid uuid references public.profiles (id) on delete set null,
  local_invoice_id integer not null,
  local_project_id integer,
  invoice_number text not null,
  status text not null default 'draft',
  total numeric not null default 0,
  currency text not null default 'USD',
  due_date timestamptz,
  payment_method text not null default '',
  payment_note text not null default '',
  client_paid_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists invoice_shares_client_email_idx on public.invoice_shares (client_email);
create index if not exists invoice_shares_client_uid_idx on public.invoice_shares (client_uid);
create index if not exists invoice_shares_freelancer_idx on public.invoice_shares (freelancer_uid);

alter table public.invoice_shares enable row level security;

drop policy if exists invoice_shares_select on public.invoice_shares;
create policy invoice_shares_select on public.invoice_shares
  for select to authenticated using (
    public.is_admin()
    or freelancer_uid = auth.uid()
    or client_uid = auth.uid()
    or client_email = public.my_email()
  );

drop policy if exists invoice_shares_write on public.invoice_shares;
create policy invoice_shares_write on public.invoice_shares
  for all to authenticated using (
    public.is_admin() or freelancer_uid = auth.uid()
  ) with check (
    public.is_admin() or freelancer_uid = auth.uid()
  );

drop policy if exists invoice_shares_client_pay on public.invoice_shares;
create policy invoice_shares_client_pay on public.invoice_shares
  for update to authenticated using (
    public.is_admin()
    or client_uid = auth.uid()
    or client_email = public.my_email()
  ) with check (
    public.is_admin()
    or client_uid = auth.uid()
    or client_email = public.my_email()
  );

alter publication supabase_realtime add table public.invoice_shares;
