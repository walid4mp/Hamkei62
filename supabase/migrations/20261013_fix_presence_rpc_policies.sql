-- Applied to project exwvavqkjrnprbyknoih on 2026-10-13.
-- Fixes: PGRST204 typing_status.action_type, ambiguous RPC overloads,
-- text-vs-uuid RPC arguments, missing policies on RLS-enabled tables,
-- missing EXECUTE grants (401 on story RPCs), realtime + replica identity.

-- 1) presence columns written by the app
alter table public.typing_status add column if not exists action_type text not null default 'none';
alter table public.group_typing_status add column if not exists action_type text not null default 'none';

-- 2) composite keys required by realtime .stream(primaryKey: ...) upserts
alter table public.typing_status drop constraint if exists typing_status_pkey;
alter table public.typing_status add constraint typing_status_pkey primary key (chat_id, user_id);
alter table public.group_typing_status drop constraint if exists group_typing_status_pkey;
alter table public.group_typing_status add constraint group_typing_status_pkey primary key (group_id, user_id);

-- 3) policies (read-all / write-own) for presence tables
alter table public.typing_status enable row level security;
alter table public.group_typing_status enable row level security;
drop policy if exists typing_status_select on public.typing_status;
create policy typing_status_select on public.typing_status for select to authenticated using (true);
drop policy if exists typing_status_insert on public.typing_status;
create policy typing_status_insert on public.typing_status for insert to authenticated with check (user_id = auth.uid());
drop policy if exists typing_status_update on public.typing_status;
create policy typing_status_update on public.typing_status for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists typing_status_delete on public.typing_status;
create policy typing_status_delete on public.typing_status for delete to authenticated using (user_id = auth.uid());
drop policy if exists group_typing_status_select on public.group_typing_status;
create policy group_typing_status_select on public.group_typing_status for select to authenticated using (true);
drop policy if exists group_typing_status_insert on public.group_typing_status;
create policy group_typing_status_insert on public.group_typing_status for insert to authenticated with check (user_id = auth.uid());
drop policy if exists group_typing_status_update on public.group_typing_status;
create policy group_typing_status_update on public.group_typing_status for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, insert, update, delete on public.typing_status, public.group_typing_status to authenticated;

-- 4) tables that had RLS enabled with no policy at all
alter table public.sticker_pack_shares enable row level security;
alter table public.group_message_mentions enable row level security;
alter table public.group_message_reactions enable row level security;
drop policy if exists sticker_pack_shares_select_authenticated on public.sticker_pack_shares;
create policy sticker_pack_shares_select_authenticated on public.sticker_pack_shares for select to authenticated using (true);
drop policy if exists sticker_pack_shares_insert_own on public.sticker_pack_shares;
create policy sticker_pack_shares_insert_own on public.sticker_pack_shares for insert to authenticated with check (shared_with_user_id = auth.uid());
drop policy if exists group_message_mentions_select_authenticated on public.group_message_mentions;
create policy group_message_mentions_select_authenticated on public.group_message_mentions for select to authenticated using (true);
drop policy if exists group_message_mentions_insert_own on public.group_message_mentions;
create policy group_message_mentions_insert_own on public.group_message_mentions for insert to authenticated with check (mentioned_user_id = auth.uid() or exists (select 1 from public.group_members gm where gm.group_id = group_message_mentions.group_id and gm.user_id = auth.uid()));
drop policy if exists group_message_reactions_select_authenticated on public.group_message_reactions;
create policy group_message_reactions_select_authenticated on public.group_message_reactions for select to authenticated using (true);
drop policy if exists group_message_reactions_insert_own on public.group_message_reactions;
create policy group_message_reactions_insert_own on public.group_message_reactions for insert to authenticated with check (user_id = auth.uid());
grant select, insert, delete on public.sticker_pack_shares, public.group_message_mentions, public.group_message_reactions to authenticated;

-- 5) ambiguous overloads -> drop the copies that do not match the app's arguments
drop function if exists public.get_ranked_home_feed(uuid, integer);
drop function if exists public.search_posts(text, uuid, integer, integer);
drop function if exists public.get_user_profile_post_ids(uuid, integer, integer);
drop function if exists public.get_messages_with_user(text);
drop function if exists public.send_message(text, text, text);
drop function if exists public.mark_messages_read(text);

-- 6) RPCs re-created on the Flutter schema (uuid ids sent as text by Dart)
drop function if exists public.get_profile_media_count(uuid);
create or replace function public.get_profile_media_count(p_user_id text)
returns bigint language sql stable set search_path to 'public' as $f$
  select count(*)::bigint from public.posts p
  where p.author_id::text = p_user_id
    and (p.image_url is not null or p.video_url is not null or p.file_url is not null);
$f$;

drop function if exists public.get_chats_with_last_message(uuid);
create or replace function public.get_chats_with_last_message(
  current_user_id text default null, p_current_user_id text default null)
returns table(conversation_user_id text, last_message_id text, last_message_body text,
  last_message_created_at timestamptz, last_message_sender_id text,
  last_message_receiver_id text, unread_count bigint)
language plpgsql stable security definer set search_path to 'public' as $f$
declare v_uid text := coalesce(current_user_id, p_current_user_id);
begin
  if v_uid is null or v_uid = '' then return; end if;
  return query
  with mine as (
    select m.*, case when m.sender_id::text = v_uid then m.receiver_id::text else m.sender_id::text end other_user_id
    from public.messages m where m.sender_id::text = v_uid or m.receiver_id::text = v_uid
  ), ranked as (
    select x.*, row_number() over (partition by x.other_user_id order by x.created_at desc, x.id desc) rn from mine x
  )
  select r.other_user_id, r.id::text,
         coalesce(nullif(r.message_text,''), nullif(r.caption,''), nullif(r.file_name,''), ''),
         r.created_at, r.sender_id::text, r.receiver_id::text,
         (select count(*)::bigint from public.messages u
           where u.sender_id::text = r.other_user_id and u.receiver_id::text = v_uid
             and coalesce(u.is_read, false) = false)
  from ranked r where r.rn = 1 order by r.created_at desc;
end $f$;

create or replace function public.get_messages_with_user(other_user_id text)
returns setof public.messages language sql stable security definer set search_path to 'public' as $f$
  select m.* from public.messages m
  where (m.sender_id::text = auth.uid()::text and m.receiver_id::text = other_user_id)
     or (m.receiver_id::text = auth.uid()::text and m.sender_id::text = other_user_id)
  order by m.created_at asc;
$f$;

-- 7) mutual friends/groups for the profile Details tab
create or replace function public.get_profile_mutuals(
  p_viewed_user_id text default null, p_current_user_id text default null)
returns table(mutual_friends_count bigint, mutual_friends_preview jsonb,
  mutual_groups_count bigint, mutual_groups_preview jsonb)
language sql stable security definer set search_path to 'public' as $f$
  with my_friends as (
    select case when f.requester_id::text = p_current_user_id then f.addressee_id::text else f.requester_id::text end uid
    from public.friendships f where f.status='accepted' and (f.requester_id::text=p_current_user_id or f.addressee_id::text=p_current_user_id)),
  their_friends as (
    select case when f.requester_id::text = p_viewed_user_id then f.addressee_id::text else f.requester_id::text end uid
    from public.friendships f where f.status='accepted' and (f.requester_id::text=p_viewed_user_id or f.addressee_id::text=p_viewed_user_id)),
  mutual as (select uid from my_friends intersect select uid from their_friends),
  my_groups as (select gm.group_id from public.group_members gm where gm.user_id::text = p_current_user_id),
  their_groups as (select gm.group_id from public.group_members gm where gm.user_id::text = p_viewed_user_id),
  mutual_g as (select group_id from my_groups intersect select group_id from their_groups)
  select (select count(*) from mutual)::bigint,
    coalesce((select jsonb_agg(jsonb_build_object('id',u.id::text,'name',coalesce(u.name,''),'image_url',u.image_url))
      from public.users u where u.id::text in (select uid from mutual)), '[]'::jsonb),
    (select count(*) from mutual_g)::bigint,
    coalesce((select jsonb_agg(jsonb_build_object('id',g.id::text,'name',coalesce(g.name,'')))
      from public.groups g where g.id in (select group_id from mutual_g)), '[]'::jsonb);
$f$;

-- 8) EXECUTE grants: story RPCs returned 401
grant execute on all functions in schema public to authenticated;
grant usage on schema public to authenticated, anon;

-- 9) realtime + replica identity for chat screens
alter publication supabase_realtime add table public.typing_status;
alter publication supabase_realtime add table public.group_typing_status;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.group_messages;
alter publication supabase_realtime add table public.user_presence;
alter publication supabase_realtime add table public.chat_mutes;
alter table public.typing_status replica identity full;
alter table public.group_typing_status replica identity full;
alter table public.messages replica identity full;
alter table public.group_messages replica identity full;

-- 10) indexes
create index if not exists typing_status_user_idx on public.typing_status (user_id);
create index if not exists group_typing_status_group_idx on public.group_typing_status (group_id);
create index if not exists messages_conversation_created_idx on public.messages (conversation_id, created_at desc);
