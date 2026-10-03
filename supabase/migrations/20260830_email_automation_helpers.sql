-- Migration: Email automation and helper procedures
-- Allows PostgreSQL cron jobs, triggers, and automations to dispatch branded transactional emails via send-clivora-email

create or replace function public.invoke_send_clivora_email(
  p_to text,
  p_subject text,
  p_purpose text,
  p_job_title text default 'Project Opportunity',
  p_company_name text default 'Hiring Team',
  p_freelancer_name text default 'CLIVORA Freelancer',
  p_amount numeric default 0,
  p_timeline_days int default 7,
  p_pitch_message text default '',
  p_review_url text default null
) returns bigint language plpgsql security definer set search_path to 'public' as $$
declare
  req_id bigint;
  secret text;
begin
  select decrypted_secret into secret
  from vault.decrypted_secrets
  where name = 'invoice_reminders_cron_secret'
  limit 1;

  -- Set vault secrets 'project_url' and 'site_url' for your project (see docs/self-hosting.md).
  p_review_url := coalesce(
    p_review_url,
    (select decrypted_secret from vault.decrypted_secrets where name = 'site_url' limit 1) || '/connect/review',
    'http://localhost:3000/connect/review'
  );

  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url' limit 1) || '/functions/v1/send-clivora-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(secret, '')
    ),
    body := jsonb_build_object(
      'to', p_to,
      'subject', p_subject,
      'purpose', p_purpose,
      'jobTitle', p_job_title,
      'companyName', p_company_name,
      'freelancerName', p_freelancer_name,
      'amount', p_amount,
      'timelineDays', p_timeline_days,
      'pitchMessage', p_pitch_message,
      'reviewUrl', p_review_url
    )
  ) into req_id;

  return req_id;
end;
$$;
