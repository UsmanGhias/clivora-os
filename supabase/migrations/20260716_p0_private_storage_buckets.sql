-- Private storage buckets for production launch (Clivora).
-- Only chat-attachments existed previously (already private).
-- Owner-folder policies: path must start with auth.uid()::text.
-- Relationship-based sharing (project/invoice ACL) is a follow-up.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp','image/gif']),
  ('portfolio-thumbs', 'portfolio-thumbs', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('portfolio-files', 'portfolio-files', false, 52428800, array['image/jpeg','image/png','image/webp','application/pdf']),
  ('contracts', 'contracts', false, 20971520, array['application/pdf','image/jpeg','image/png']),
  ('invoice-docs', 'invoice-docs', false, 20971520, array['application/pdf','image/jpeg','image/png']),
  ('project-files', 'project-files', false, 52428800, array['application/pdf','image/jpeg','image/png','image/webp','text/plain']),
  ('dispute-evidence', 'dispute-evidence', false, 20971520, array['application/pdf','image/jpeg','image/png']),
  ('identity-docs', 'identity-docs', false, 10485760, array['application/pdf','image/jpeg','image/png']),
  ('support-attachments', 'support-attachments', false, 20971520, array['application/pdf','image/jpeg','image/png','text/plain']),
  ('temp-exports', 'temp-exports', false, 52428800, null)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Helper: owner folder = first path segment equals auth.uid()
-- Apply to each private bucket.

do $$
declare
  b text;
  buckets text[] := array[
    'portfolio-files','contracts','invoice-docs','project-files',
    'dispute-evidence','identity-docs','support-attachments','temp-exports','chat-attachments'
  ];
begin
  foreach b in array buckets loop
    execute format('drop policy if exists %I on storage.objects', b || '_owner_select');
    execute format('drop policy if exists %I on storage.objects', b || '_owner_insert');
    execute format('drop policy if exists %I on storage.objects', b || '_owner_update');
    execute format('drop policy if exists %I on storage.objects', b || '_owner_delete');

    execute format($f$
      create policy %I on storage.objects for select to authenticated
      using (bucket_id = %L and (storage.foldername(name))[1] = auth.uid()::text)
    $f$, b || '_owner_select', b);

    execute format($f$
      create policy %I on storage.objects for insert to authenticated
      with check (bucket_id = %L and (storage.foldername(name))[1] = auth.uid()::text)
    $f$, b || '_owner_insert', b);

    execute format($f$
      create policy %I on storage.objects for update to authenticated
      using (bucket_id = %L and (storage.foldername(name))[1] = auth.uid()::text)
      with check (bucket_id = %L and (storage.foldername(name))[1] = auth.uid()::text)
    $f$, b || '_owner_update', b, b);

    execute format($f$
      create policy %I on storage.objects for delete to authenticated
      using (bucket_id = %L and (storage.foldername(name))[1] = auth.uid()::text)
    $f$, b || '_owner_delete', b);
  end loop;
end $$;

-- Public read for avatars + portfolio thumbs; owner write still folder-scoped.
drop policy if exists avatars_public_select on storage.objects;
create policy avatars_public_select on storage.objects
  for select to public using (bucket_id = 'avatars');

drop policy if exists avatars_owner_write on storage.objects;
create policy avatars_owner_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_owner_update on storage.objects;
create policy avatars_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_owner_delete on storage.objects;
create policy avatars_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists portfolio_thumbs_public_select on storage.objects;
create policy portfolio_thumbs_public_select on storage.objects
  for select to public using (bucket_id = 'portfolio-thumbs');

drop policy if exists portfolio_thumbs_owner_write on storage.objects;
create policy portfolio_thumbs_owner_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'portfolio-thumbs' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists portfolio_thumbs_owner_update on storage.objects;
create policy portfolio_thumbs_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'portfolio-thumbs' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists portfolio_thumbs_owner_delete on storage.objects;
create policy portfolio_thumbs_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'portfolio-thumbs' and (storage.foldername(name))[1] = auth.uid()::text);
