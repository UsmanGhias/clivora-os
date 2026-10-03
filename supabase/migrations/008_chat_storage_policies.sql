-- CLIVORA v2.3.9 — fix chat image uploads (403) for all users (Free + Pro)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-attachments',
  'chat-attachments',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

drop policy if exists chat_attachments_read on storage.objects;
drop policy if exists chat_attachments_upload on storage.objects;
drop policy if exists chat_attachments_insert on storage.objects;
drop policy if exists chat_attachments_update on storage.objects;
drop policy if exists chat_attachments_delete on storage.objects;
drop policy if exists "chat_attachments_public_read" on storage.objects;
drop policy if exists "chat_attachments_auth_insert" on storage.objects;
drop policy if exists "chat_attachments_auth_update" on storage.objects;
drop policy if exists "chat_attachments_auth_delete" on storage.objects;

create policy "chat_attachments_public_read"
  on storage.objects for select
  using (bucket_id = 'chat-attachments');

create policy "chat_attachments_auth_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and (string_to_array(name, '/'))[1] = auth.uid()::text
  );

create policy "chat_attachments_auth_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (string_to_array(name, '/'))[1] = auth.uid()::text
  );

create policy "chat_attachments_auth_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (string_to_array(name, '/'))[1] = auth.uid()::text
  );
