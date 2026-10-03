-- Ops: activate promo + daily invoice reminder cron (pg_cron + pg_net + vault)
-- Cron secret is stored in vault (invoice_reminders_cron_secret), not in this file.

update public.promo_codes
set is_active = true,
    max_uses = least(coalesce(max_uses, 100), 50)
where code = 'CLIVORA15';

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create or replace function public.invoke_invoice_reminders()
returns bigint
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  req_id bigint;
  secret text;
begin
  select decrypted_secret into secret
  from vault.decrypted_secrets
  where name = 'invoice_reminders_cron_secret'
  limit 1;

  if secret is null or length(secret) < 8 then
    raise exception 'invoice_reminders_cron_secret missing in vault';
  end if;

  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url' limit 1) || '/functions/v1/send-invoice-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || secret
    ),
    body := jsonb_build_object('source', 'pg_cron', 'at', now())
  ) into req_id;

  return req_id;
end;
$$;

revoke all on function public.invoke_invoice_reminders() from public;
grant execute on function public.invoke_invoice_reminders() to postgres;
