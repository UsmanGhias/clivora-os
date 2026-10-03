-- CLIVORA 2.14: Connect reputation aggregates + trust signals + promo codes

alter table public.connect_profiles
  add column if not exists avg_rating numeric(3,2) not null default 0,
  add column if not exists review_count integer not null default 0,
  add column if not exists completion_rate numeric(5,2) not null default 0,
  add column if not exists reputation_score numeric(8,2) not null default 0,
  add column if not exists profile_completeness integer not null default 0;

create index if not exists connect_profiles_reputation_idx
  on public.connect_profiles (reputation_score desc);
create index if not exists connect_profiles_avg_rating_idx
  on public.connect_profiles (avg_rating desc, review_count desc);

create or replace function public.refresh_connect_reputation(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg numeric(3,2);
  v_count integer;
  v_completion numeric(5,2);
  v_verified boolean;
  v_score numeric(8,2);
  v_complete integer;
begin
  select coalesce(avg(rating)::numeric(3,2), 0), count(*)::integer
    into v_avg, v_count
  from public.connect_reviews
  where to_user_id = p_user_id;

  select case
           when count(*) = 0 then 0
           else round(100.0 * count(*) filter (where status = 'released') / count(*), 2)
         end
    into v_completion
  from public.connect_milestones
  where freelancer_user_id = p_user_id;

  select is_verified,
         (
           case when coalesce(nullif(trim(display_title), ''), '') <> '' then 20 else 0 end +
           case when coalesce(nullif(trim(headline), ''), '') <> '' then 15 else 0 end +
           case when coalesce(nullif(trim(bio), ''), '') <> '' then 20 else 0 end +
           case when coalesce(array_length(skills, 1), 0) > 0 then 15 else 0 end +
           case when coalesce(nullif(trim(rate_band), ''), '') <> '' then 10 else 0 end +
           case when coalesce(nullif(trim(availability), ''), '') <> '' then 10 else 0 end +
           case when coalesce(nullif(trim(location_label), ''), '') <> '' then 10 else 0 end
         )
    into v_verified, v_complete
  from public.connect_profiles
  where user_id = p_user_id;

  if not found then
    return;
  end if;

  v_score := (coalesce(v_avg, 0) * 12)
           + least(coalesce(v_count, 0), 40)::numeric
           + case when coalesce(v_verified, false) then 20 else 0 end
           + (coalesce(v_completion, 0) * 0.2)
           + (coalesce(v_complete, 0) * 0.15);

  update public.connect_profiles
  set avg_rating = coalesce(v_avg, 0),
      review_count = coalesce(v_count, 0),
      completion_rate = coalesce(v_completion, 0),
      profile_completeness = coalesce(v_complete, 0),
      reputation_score = coalesce(v_score, 0),
      updated_at = now()
  where user_id = p_user_id;
end;
$$;

create or replace function public.trg_connect_reviews_refresh_reputation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_connect_reputation(old.to_user_id);
    return old;
  end if;
  perform public.refresh_connect_reputation(new.to_user_id);
  if tg_op = 'UPDATE' and old.to_user_id is distinct from new.to_user_id then
    perform public.refresh_connect_reputation(old.to_user_id);
  end if;
  return new;
end;
$$;

drop trigger if exists connect_reviews_refresh_reputation on public.connect_reviews;
create trigger connect_reviews_refresh_reputation
  after insert or update or delete on public.connect_reviews
  for each row execute function public.trg_connect_reviews_refresh_reputation();

create or replace function public.trg_connect_milestones_refresh_reputation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_connect_reputation(old.freelancer_user_id);
    return old;
  end if;
  perform public.refresh_connect_reputation(new.freelancer_user_id);
  return new;
end;
$$;

drop trigger if exists connect_milestones_refresh_reputation on public.connect_milestones;
create trigger connect_milestones_refresh_reputation
  after insert or update or delete on public.connect_milestones
  for each row execute function public.trg_connect_milestones_refresh_reputation();

create or replace function public.trg_connect_profiles_completeness()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.profile_completeness :=
    case when coalesce(nullif(trim(new.display_title), ''), '') <> '' then 20 else 0 end +
    case when coalesce(nullif(trim(new.headline), ''), '') <> '' then 15 else 0 end +
    case when coalesce(nullif(trim(new.bio), ''), '') <> '' then 20 else 0 end +
    case when coalesce(array_length(new.skills, 1), 0) > 0 then 15 else 0 end +
    case when coalesce(nullif(trim(new.rate_band), ''), '') <> '' then 10 else 0 end +
    case when coalesce(nullif(trim(new.availability), ''), '') <> '' then 10 else 0 end +
    case when coalesce(nullif(trim(new.location_label), ''), '') <> '' then 10 else 0 end;
  new.reputation_score := (coalesce(new.avg_rating, 0) * 12)
    + least(coalesce(new.review_count, 0), 40)::numeric
    + case when coalesce(new.is_verified, false) then 20 else 0 end
    + (coalesce(new.completion_rate, 0) * 0.2)
    + (coalesce(new.profile_completeness, 0) * 0.15);
  return new;
end;
$$;

drop trigger if exists connect_profiles_completeness on public.connect_profiles;
create trigger connect_profiles_completeness
  before insert or update of display_title, headline, bio, skills, rate_band, availability, location_label, is_verified, avg_rating, review_count, completion_rate
  on public.connect_profiles
  for each row execute function public.trg_connect_profiles_completeness();

do $$
declare
  r record;
begin
  for r in select user_id from public.connect_profiles loop
    perform public.refresh_connect_reputation(r.user_id);
  end loop;
end;
$$;

create table if not exists public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount_type text not null default 'percent',
  discount_value numeric not null default 0,
  applies_to text not null default 'any',
  max_uses integer,
  used_count integer not null default 0,
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint promo_codes_type_chk check (discount_type in ('percent', 'fixed')),
  constraint promo_codes_applies_chk check (applies_to in ('any', 'pro', 'pro_plus'))
);

alter table public.promo_codes enable row level security;
drop policy if exists promo_codes_public_read on public.promo_codes;
create policy promo_codes_public_read on public.promo_codes
  for select to authenticated
  using (is_active = true and (expires_at is null or expires_at > now()));
