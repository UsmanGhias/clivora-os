-- High-impact portal/connect fixes:
-- 1) Freelancers can publish "needs" as the web/mobile UI already allows.
-- 2) Linked clients can message freelancers; the previous trigger compared the
--    freelancer email to the sender email instead of the recipient email.
-- 3) Guests can validate active checkout promo codes without an authenticated
--    session; only active, non-expired promo metadata is exposed.

drop policy if exists promo_codes_public_read on public.promo_codes;
create policy promo_codes_public_read on public.promo_codes
  for select to anon, authenticated
  using (is_active = true and (expires_at is null or expires_at > now()));

grant select on public.promo_codes to anon, authenticated;

create or replace function public.connect_publish_need(
  p_title text, p_summary text, p_skills text[], p_budget_band text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare v_id uuid := gen_random_uuid();
begin
  if not exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and account_type in ('client', 'freelancer', 'admin')
  ) then
    raise exception 'ACTION_NOT_ALLOWED';
  end if;

  perform public.connect_spend_credits('publish_need', 'connect_need', v_id, 'publish_need:' || v_id::text);
  insert into public.connect_need_posts
    (id, client_user_id, title, summary, skills, budget_band, is_open, moderation_status)
  values (v_id, auth.uid(), left(coalesce(p_title, ''), 200), coalesce(p_summary, ''), coalesce(p_skills, '{}'),
    left(coalesce(p_budget_band, ''), 120), true, 'pending');
  return v_id;
end;
$$;

grant execute on function public.connect_publish_need(text, text, text[], text) to authenticated;

create or replace function public.require_message_link()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if exists (
    select 1 from public.project_shares ps
    where (ps.freelancer_uid = new.from_uid and lower(ps.client_email) = lower(new.to_email))
       or (ps.client_uid = new.from_uid and lower(ps.freelancer_email) = lower(new.to_email))
  ) then
    return new;
  end if;

  if exists (
    select 1 from public.client_messages cm
    where (cm.from_uid = new.from_uid and lower(cm.to_email) = lower(new.to_email))
       or (cm.to_uid = new.from_uid and lower(cm.from_email) = lower(new.from_email))
       or (cm.from_uid = new.to_uid and lower(cm.to_email) = lower(new.from_email))
       or (lower(cm.to_email) = lower(new.from_email) and cm.from_uid = new.from_uid)
  ) then
    return new;
  end if;

  if exists (
    select 1 from public.invoice_shares inv
    where (inv.freelancer_uid = new.from_uid and lower(inv.client_email) = lower(new.to_email))
       or (inv.client_uid = new.from_uid and lower(inv.freelancer_email) = lower(new.to_email))
  ) then
    return new;
  end if;

  raise exception 'You can only message linked contacts on shared projects.';
end;
$$;
