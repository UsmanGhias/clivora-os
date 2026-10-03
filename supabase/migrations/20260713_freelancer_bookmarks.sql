-- Freelancer bookmarks for portal saved items
create table if not exists public.freelancer_bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('project','client','freelancer','job','collection')),
  target_id text not null,
  title text,
  meta jsonb not null default '{}'::jsonb,
  collection text,
  created_at timestamptz not null default now(),
  unique (user_id, target_type, target_id)
);

create index if not exists freelancer_bookmarks_user_idx
  on public.freelancer_bookmarks (user_id, created_at desc);

alter table public.freelancer_bookmarks enable row level security;

drop policy if exists freelancer_bookmarks_owner on public.freelancer_bookmarks;
create policy freelancer_bookmarks_owner on public.freelancer_bookmarks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
