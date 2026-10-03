-- Profile photo URL (storage public URL or data URL fallback)
alter table public.profiles add column if not exists avatar_url text;
comment on column public.profiles.avatar_url is 'Public URL or data URL for profile photo';
