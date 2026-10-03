-- Phase 1 foundation: LWW sync, sync_status, custom_fields prep, messaging v2, invoice tax lines
-- CLIVORA 2.11

-- ─── sync_status + custom_fields on CRM ───────────────────────────────────────
alter table public.crm_customers
  add column if not exists sync_status text not null default 'synced',
  add column if not exists custom_fields jsonb not null default '{}'::jsonb;

alter table public.crm_projects
  add column if not exists sync_status text not null default 'synced',
  add column if not exists custom_fields jsonb not null default '{}'::jsonb,
  add column if not exists board_order integer not null default 0;

alter table public.crm_invoices
  add column if not exists sync_status text not null default 'synced',
  add column if not exists tax_lines jsonb not null default '[]'::jsonb,
  add column if not exists reminder_sent_at timestamptz,
  add column if not exists next_reminder_at timestamptz;

alter table public.crm_expenses
  add column if not exists sync_status text not null default 'synced';

alter table public.crm_notes
  add column if not exists sync_status text not null default 'synced',
  add column if not exists customer_id uuid references public.crm_customers(id) on delete set null,
  add column if not exists project_id uuid references public.crm_projects(id) on delete set null;

-- ─── Last-write-wins: reject stale updates ───────────────────────────────────
create or replace function public.crm_reject_stale_update()
returns trigger
language plpgsql
as $$
begin
  if old.updated_at is not null
     and new.updated_at is not null
     and new.updated_at < old.updated_at then
    raise exception 'STALE_UPDATE: incoming updated_at (%) is older than current (%)',
      new.updated_at, old.updated_at
      using errcode = 'P0001';
  end if;
  if new.updated_at is null or new.updated_at < now() - interval '1 second' then
    new.updated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists crm_customers_lww on public.crm_customers;
create trigger crm_customers_lww
  before update on public.crm_customers
  for each row execute function public.crm_reject_stale_update();

drop trigger if exists crm_projects_lww on public.crm_projects;
create trigger crm_projects_lww
  before update on public.crm_projects
  for each row execute function public.crm_reject_stale_update();

drop trigger if exists crm_invoices_lww on public.crm_invoices;
create trigger crm_invoices_lww
  before update on public.crm_invoices
  for each row execute function public.crm_reject_stale_update();

drop trigger if exists crm_expenses_lww on public.crm_expenses;
create trigger crm_expenses_lww
  before update on public.crm_expenses
  for each row execute function public.crm_reject_stale_update();

drop trigger if exists crm_notes_lww on public.crm_notes;
create trigger crm_notes_lww
  before update on public.crm_notes
  for each row execute function public.crm_reject_stale_update();

-- ─── Messaging v2: threads, read receipts, attachments meta ──────────────────
alter table public.client_messages
  add column if not exists parent_message_id uuid references public.client_messages(id) on delete set null,
  add column if not exists read_at timestamptz,
  add column if not exists attachments jsonb not null default '[]'::jsonb;

create index if not exists client_messages_parent_idx
  on public.client_messages (parent_message_id)
  where parent_message_id is not null;

-- ─── Invoice payment allocations (partial payments) ──────────────────────────
create table if not exists public.crm_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references auth.users(id) on delete cascade,
  invoice_id uuid not null references public.crm_invoices(id) on delete cascade,
  amount numeric not null default 0,
  currency text not null default 'USD',
  method text not null default 'other',
  reference text not null default '',
  notes text not null default '',
  paid_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists crm_payment_allocations_invoice_idx
  on public.crm_payment_allocations (invoice_id);

alter table public.crm_payment_allocations enable row level security;
drop policy if exists crm_payment_allocations_owner on public.crm_payment_allocations;
create policy crm_payment_allocations_owner on public.crm_payment_allocations
  for all to authenticated
  using (owner_uid = auth.uid())
  with check (owner_uid = auth.uid());

-- Keep invoice status in sync when amount_paid updates
create or replace function public.crm_invoice_payment_status()
returns trigger
language plpgsql
as $$
begin
  if new.amount_paid <= 0 then
    if new.status = 'paid' or new.status = 'partial' then
      new.status := 'sent';
    end if;
  elsif new.amount_paid >= new.total and new.total > 0 then
    new.status := 'paid';
  elsif new.amount_paid > 0 and new.amount_paid < new.total then
    new.status := 'partial';
  end if;
  return new;
end;
$$;

drop trigger if exists crm_invoices_payment_status on public.crm_invoices;
create trigger crm_invoices_payment_status
  before update of amount_paid, total on public.crm_invoices
  for each row execute function public.crm_invoice_payment_status();
