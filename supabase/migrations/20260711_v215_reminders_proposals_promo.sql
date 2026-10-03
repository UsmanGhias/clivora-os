-- CLIVORA 2.15: promo on payment requests, proposal RLS, reminder scheduling

alter table public.pro_payment_requests
  add column if not exists promo_code text,
  add column if not exists amount_usd numeric;

drop policy if exists connect_proposals_parties on public.connect_proposals;
create policy connect_proposals_parties on public.connect_proposals
  for all to authenticated
  using (from_user_id = auth.uid() or to_user_id = auth.uid())
  with check (from_user_id = auth.uid() or to_user_id = auth.uid());

insert into public.promo_codes (code, discount_type, discount_value, applies_to, max_uses, is_active, expires_at)
values ('CLIVORA15', 'percent', 15, 'any', 100, false, now() + interval '180 days')
on conflict (code) do nothing;

create or replace function public.schedule_invoice_reminder()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('sent','overdue','partial','unpaid') and new.due_date is not null then
    if new.next_reminder_at is null then
      new.next_reminder_at := greatest(new.due_date, now()) + interval '1 day';
    end if;
  elsif new.status in ('paid','void','cancelled','draft') then
    new.next_reminder_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists crm_invoices_schedule_reminder on public.crm_invoices;
create trigger crm_invoices_schedule_reminder
  before insert or update of status, due_date on public.crm_invoices
  for each row execute function public.schedule_invoice_reminder();

update public.crm_invoices
set next_reminder_at = greatest(coalesce(due_date, now()), now())
where next_reminder_at is null
  and status in ('sent','overdue','partial','unpaid')
  and due_date is not null
  and due_date <= now();
