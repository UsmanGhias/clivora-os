-- Public vault share lookup RPC (additive, idempotent).
-- Exported from live Supabase (vault_share_public_lookup).
-- Depends on vault_share_links from phase0_foundations.

begin;

create or replace function public.vault_lookup_share_by_token(p_token text)
returns table(
  id uuid,
  file_name text,
  storage_path text,
  expires_at timestamptz,
  max_downloads integer,
  download_count integer
)
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  return query
  select v.id, v.file_name, v.storage_path, v.expires_at, v.max_downloads, v.download_count
  from public.vault_share_links v
  where v.token = p_token
  limit 1;
end;
$function$;

revoke all on function public.vault_lookup_share_by_token(text) from public;
grant execute on function public.vault_lookup_share_by_token(text) to anon, authenticated;

commit;
