-- Client portal: shared time entry access + column aliases used by web UI
alter table public.crm_time_entries
  add column if not exists hours numeric,
  add column if not exists date date,
  add column if not exists status text,
  add column if not exists customer_id uuid;

update public.crm_time_entries
set
  hours = coalesce(hours, round((coalesce(minutes, 0)::numeric / 60.0), 2)),
  date = coalesce(date, work_date),
  status = coalesce(nullif(status, ''), approval_status, 'pending')
where hours is null or date is null or status is null;

drop policy if exists crm_time_entries_shared_client_select on public.crm_time_entries;
create policy crm_time_entries_shared_client_select on public.crm_time_entries
  for select to authenticated
  using (
    owner_uid = auth.uid()
    or exists (
      select 1
      from public.project_shares ps
      where ps.freelancer_uid = crm_time_entries.owner_uid
        and (
          ps.client_uid = auth.uid()
          or lower(ps.client_email) = lower(coalesce(public.my_email(), ''))
        )
    )
  );

drop policy if exists crm_time_entries_shared_client_update on public.crm_time_entries;
create policy crm_time_entries_shared_client_update on public.crm_time_entries
  for update to authenticated
  using (
    owner_uid = auth.uid()
    or exists (
      select 1
      from public.project_shares ps
      where ps.freelancer_uid = crm_time_entries.owner_uid
        and (
          ps.client_uid = auth.uid()
          or lower(ps.client_email) = lower(coalesce(public.my_email(), ''))
        )
    )
  )
  with check (
    owner_uid = auth.uid()
    or exists (
      select 1
      from public.project_shares ps
      where ps.freelancer_uid = crm_time_entries.owner_uid
        and (
          ps.client_uid = auth.uid()
          or lower(ps.client_email) = lower(coalesce(public.my_email(), ''))
        )
    )
  );
