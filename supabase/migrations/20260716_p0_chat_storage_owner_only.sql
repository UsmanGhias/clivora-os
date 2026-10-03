-- P0: chat-attachments private + owner-folder isolation (master production plan §5)
-- Forward-only: safe to re-run drops/creates.

update storage.buckets
set
  public = false,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
where id = 'chat-attachments';

-- Drop legacy permissive policies (any authenticated user could SELECT all objects).
drop policy if exists "chat_attachments_public_read" on storage.objects;
drop policy if exists "chat_attachments_auth_read" on storage.objects;
drop policy if exists chat_attachments_read on storage.objects;
drop policy if exists "chat_attachments_auth_insert" on storage.objects;
drop policy if exists "chat_attachments_auth_update" on storage.objects;
drop policy if exists "chat_attachments_auth_delete" on storage.objects;
drop policy if exists chat_attachments_insert on storage.objects;
drop policy if exists chat_attachments_update on storage.objects;
drop policy if exists chat_attachments_delete on storage.objects;

-- Owner-only: path must start with auth.uid()/
create policy "chat_attachments_owner_select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "chat_attachments_owner_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "chat_attachments_owner_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "chat_attachments_owner_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
