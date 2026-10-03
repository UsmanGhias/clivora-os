-- CLIVORA — invoice share link expiry (90 days default)

alter table public.invoice_shares
  add column if not exists expires_at timestamptz;

update public.invoice_shares
set expires_at = coalesce(updated_at, now()) + interval '90 days'
where expires_at is null;

create index if not exists invoice_shares_expires_at_idx
  on public.invoice_shares (expires_at);
