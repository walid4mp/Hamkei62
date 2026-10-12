-- ============================================================================
-- Storage buckets — chat media uploads
-- The Flutter upload code expects buckets named "chat-media" and "avatars".
-- Idempotent: re-running will not throw.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('stories', 'stories', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('posts', 'posts', true)
on conflict (id) do nothing;

-- Drop and re-create read-all storage policies (the app uses anon key reads).
drop policy if exists "Public read chat-media" on storage.objects;
create policy "Public read chat-media"
  on storage.objects for select using (bucket_id = 'chat-media');

drop policy if exists "Public read avatars" on storage.objects;
create policy "Public read avatars"
  on storage.objects for select using (bucket_id = 'avatars');

drop policy if exists "Public read stories" on storage.objects;
create policy "Public read stories"
  on storage.objects for select using (bucket_id = 'stories');

drop policy if exists "Public read posts" on storage.objects;
create policy "Public read posts"
  on storage.objects for select using (bucket_id = 'posts');
