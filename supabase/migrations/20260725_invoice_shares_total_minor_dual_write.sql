-- WEB-005: keep invoice_shares.total_minor in sync with numeric total.
-- Applied live as invoice_shares_total_minor_dual_write (2026-07-25).

alter table public.invoice_shares
  add column if not exists total_minor bigint;

update public.invoice_shares
set total_minor = round(coalesce(total, 0) * 100)::bigint
where total_minor is null and total is not null;

create or replace function public.invoice_shares_sync_total_minor()
returns trigger
language plpgsql
as $$
begin
  if new.total is not null then
    new.total_minor := round(new.total * 100)::bigint;
  elsif new.total_minor is null then
    new.total_minor := 0;
  end if;
  return new;
end;
$$;

drop trigger if exists invoice_shares_sync_total_minor_trg on public.invoice_shares;
create trigger invoice_shares_sync_total_minor_trg
before insert or update of total, total_minor
on public.invoice_shares
for each row
execute function public.invoice_shares_sync_total_minor();

-- AUTO-003: unique idempotency key when present (ignore-duplicates on enqueue).
create unique index if not exists automation_webhook_queue_idempotency_key_uidx
  on public.automation_webhook_queue (idempotency_key)
  where idempotency_key is not null;
