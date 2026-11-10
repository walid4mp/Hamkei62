-- Storage bucket: media (avatars, posts, stories, reels, chat attachments)
insert into storage.buckets (id, name, public) values ('media', 'media', true)
on conflict (id) do nothing;

create policy "media_public_read" on storage.objects for select using (bucket_id = 'media');
create policy "media_auth_upload" on storage.objects for insert
  with check (bucket_id = 'media' and auth.role() = 'authenticated');
create policy "media_owner_delete" on storage.objects for delete
  using (bucket_id = 'media' and auth.uid()::text = (storage.foldername(name))[2]);
