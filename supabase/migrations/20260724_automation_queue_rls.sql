-- Owner RLS for automation_webhook_queue (additive, idempotent).
-- Exported from live Supabase (phase0_queue_rls_owner_policies).
-- Depends on automation_webhook_queue.owner_uid from phase0_foundations.

begin;

alter table public.automation_webhook_queue enable row level security;

drop policy if exists automation_webhook_queue_select on public.automation_webhook_queue;
create policy automation_webhook_queue_select on public.automation_webhook_queue
  for select to authenticated
  using (owner_uid = auth.uid() or is_admin());

drop policy if exists automation_webhook_queue_insert on public.automation_webhook_queue;
create policy automation_webhook_queue_insert on public.automation_webhook_queue
  for insert to authenticated
  with check (owner_uid = auth.uid() or is_admin());

drop policy if exists automation_webhook_queue_update on public.automation_webhook_queue;
create policy automation_webhook_queue_update on public.automation_webhook_queue
  for update to authenticated
  using (owner_uid = auth.uid() or is_admin())
  with check (owner_uid = auth.uid() or is_admin());

commit;
