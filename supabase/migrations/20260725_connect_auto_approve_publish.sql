-- Connect production launch: honor admin auto-approve settings on publish,
-- and approve already-listed pending rows so browse boards are not empty.

create or replace function public.connect_auto_approve_enabled(p_key text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select (value->>'enabled')::boolean
      from public.app_settings
      where key = p_key
      limit 1
    ),
    true
  );
$$;

create or replace function public.connect_publish_need(
  p_title text, p_summary text, p_skills text[], p_budget_band text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid := gen_random_uuid();
  v_status text := case
    when public.connect_auto_approve_enabled('connect_auto_approve_needs') then 'approved'
    else 'pending'
  end;
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
  values (
    v_id,
    auth.uid(),
    left(coalesce(p_title, ''), 200),
    coalesce(p_summary, ''),
    coalesce(p_skills, '{}'),
    left(coalesce(p_budget_band, ''), 120),
    true,
    v_status
  );
  return v_id;
end;
$$;

create or replace function public.connect_publish_profile(
  p_headline text, p_bio text, p_skills text[], p_rate numeric)
returns uuid language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid := auth.uid();
  v_status text := case
    when public.connect_auto_approve_enabled('connect_auto_approve_profiles') then 'approved'
    else 'pending'
  end;
begin
  if v_id is null or not exists (
    select 1 from public.profiles where id = v_id and account_type = 'freelancer'
  ) then
    raise exception 'ACTION_NOT_ALLOWED';
  end if;

  perform public.connect_spend_credits(
    'publish_profile', 'connect_profile', v_id, 'publish_profile:' || v_id::text
  );

  insert into public.connect_profiles (
    user_id, display_title, headline, bio, skills, rate_band, is_listed, moderation_status, account_type
  )
  values (
    v_id,
    left(coalesce(p_headline, ''), 200),
    left(coalesce(p_headline, ''), 200),
    coalesce(p_bio, ''),
    coalesce(p_skills, '{}'),
    left(coalesce(p_rate, 0)::text, 80),
    true,
    v_status,
    'freelancer'
  )
  on conflict (user_id) do update set
    headline = excluded.headline,
    bio = excluded.bio,
    skills = excluded.skills,
    rate_band = excluded.rate_band,
    is_listed = true,
    moderation_status = excluded.moderation_status,
    updated_at = now();

  return v_id;
end;
$$;

-- When a profile becomes listed via direct upsert (clients), auto-approve if enabled.
create or replace function public.connect_profiles_auto_approve_listed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_listed is true
     and coalesce(new.moderation_status, 'pending') in ('pending', 'draft', '')
     and public.connect_auto_approve_enabled('connect_auto_approve_profiles') then
    new.moderation_status := 'approved';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_connect_profiles_auto_approve on public.connect_profiles;
create trigger trg_connect_profiles_auto_approve
  before insert or update of is_listed, moderation_status
  on public.connect_profiles
  for each row
  execute function public.connect_profiles_auto_approve_listed();

-- Day-one backfill so existing listed rows appear in browse.
update public.connect_profiles
set moderation_status = 'approved', updated_at = now()
where is_listed = true
  and coalesce(moderation_status, 'pending') in ('pending', 'draft');

update public.connect_need_posts
set moderation_status = 'approved', updated_at = now()
where is_open = true
  and coalesce(moderation_status, 'pending') = 'pending';

grant execute on function public.connect_auto_approve_enabled(text) to authenticated;
grant execute on function public.connect_publish_need(text, text, text[], text) to authenticated;
grant execute on function public.connect_publish_profile(text, text, text[], numeric) to authenticated;
