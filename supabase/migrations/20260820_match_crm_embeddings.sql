-- Optional vector match for Ask AI. Safe to apply later; Ask AI still works if this RPC is missing.
-- Do not run against production until a maintenance window is agreed.

create or replace function public.match_crm_embeddings(
  query_embedding vector(1536),
  match_owner uuid,
  match_count int default 8
)
returns table (
  entity_type text,
  entity_id uuid,
  content text,
  similarity float
)
language sql
stable
as $$
  select
    e.entity_type,
    e.entity_id,
    e.content,
    (1 - (e.embedding <=> query_embedding))::float as similarity
  from public.crm_embeddings e
  where e.owner_uid = match_owner
    and e.embedding is not null
  order by e.embedding <=> query_embedding
  limit greatest(1, least(match_count, 24));
$$;

grant execute on function public.match_crm_embeddings(vector, uuid, int) to authenticated;
