-- CLIVORA — private chat attachments (signed URLs only)

update storage.buckets
set public = false
where id = 'chat-attachments';

drop policy if exists "chat_attachments_public_read" on storage.objects;

create policy "chat_attachments_auth_read"
  on storage.objects for select to authenticated
  using (bucket_id = 'chat-attachments');
