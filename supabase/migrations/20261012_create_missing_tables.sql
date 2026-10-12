-- ============================================================================
-- Hamkei62 / Social Mate — Create the four tables the Flutter app calls
-- which were missing from the project `exwvavqkjrnprbyknoih`.
--
-- Idempotent: each CREATE uses IF NOT EXISTS where Postgres allows it, and
-- any ALTER that is a no-op is guarded with to_regclass / information_schema.
--
-- This migration DOES NOT touch any of the 27 tables that already exist.
-- Run this in the Supabase SQL Editor of project exwvavqkjrnprbyknoih:
--   1. Open https://supabase.com/dashboard/project/exwvavqkjrnprbyknoih/sql/new
--   2. Paste this entire file
--   3. Run it
-- SQL Editor does not require a password; only direct DB connections do.
-- ============================================================================

-- 0. Required extensions (Supabase enables pgcrypto by default, but make sure)
create extension if not exists "pgcrypto" with schema extensions;

-- ============================================================================
-- 1. user_sticker_packs — used by stickers_repository.createUserStickerPackRpc
-- ============================================================================
create table if not exists public.user_sticker_packs (
  id              uuid primary key default extensions.gen_random_uuid(),
  owner_id        uuid not null references public.users(id) on delete cascade,
  title           text not null,
  cover_url       text,
  sticker_count   integer not null default 0,
  total_size_bytes bigint not null default 0,
  sort_order      integer not null default 0,
  has_animated    boolean not null default false,
  privacy_level   text not null default 'private'
                  check (privacy_level in ('private','friends','public')),
  created_at      timestamptz not null default now()
);

create index if not exists user_sticker_packs_owner_id_idx
  on public.user_sticker_packs (owner_id, sort_order, created_at desc);

-- ============================================================================
-- 2. reels_videos — populated by reels ingestion workers; the Flutter code
--    selects from a `reels_videos` table that needs to exist even if empty.
-- ============================================================================
create table if not exists public.reels_videos (
  id              uuid primary key default extensions.gen_random_uuid(),
  youtube_video_id text unique,
  channel_id      uuid references public.reel_channels(id) on delete set null,
  title           text,
  description     text,
  thumbnail_url   text,
  duration_seconds integer,
  original_like_count  bigint not null default 0,
  original_view_count  bigint not null default 0,
  published_at    timestamptz,
  created_at      timestamptz not null default now()
);

create index if not exists reels_videos_published_at_idx
  on public.reels_videos (published_at desc nulls last);

-- ============================================================================
-- 3. fcm_tokens — used by FCM service to push per-user notifications
-- ============================================================================
create table if not exists public.fcm_tokens (
  id              uuid primary key default extensions.gen_random_uuid(),
  user_id         uuid not null references public.users(id) on delete cascade,
  token           text not null,
  platform        text not null default 'android'
                  check (platform in ('android','ios','web','other')),
  device_id       text,
  app_version     text,
  updated_at      timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists fcm_tokens_user_id_idx
  on public.fcm_tokens (user_id);

-- ============================================================================
-- 4. comments_likes — used by comments service like-toggle (legacy + future)
--    comment_reactions already exists; this table is the simple counter.
-- ============================================================================
create table if not exists public.comments_likes (
  id              uuid primary key default extensions.gen_random_uuid(),
  comment_id      uuid not null references public.comments(id) on delete cascade,
  user_id         uuid not null references public.users(id) on delete cascade,
  created_at      timestamptz not null default now(),
  unique (comment_id, user_id)
);

create index if not exists comments_likes_comment_id_idx
  on public.comments_likes (comment_id);

-- ============================================================================
-- 5. Helpful ADD COLUMN bash-ups on existing tables where the Flutter code
--    references a column the schema did not originally define.
-- ============================================================================
-- posts: link_share_count / pinned_count / updated_at / is_suggested_for_you
alter table public.posts
  add column if not exists link_share_count integer not null default 0,
  add column if not exists pinned_count     integer not null default 0,
  add column if not exists updated_at       timestamptz,
  add column if not exists is_suggested_for_you boolean not null default false;

-- users: presence fields used by the cubit
alter table public.users
  add column if not exists tagline text,
  add column if not exists is_tagline_hidden boolean not null default false,
  add column if not exists theme text,
  add column if not exists presence_privacy text not null default 'everyone',
  add column if not exists presence_visible_to text[] not null default '{}',
  add column if not exists social_links jsonb not null default '{}'::jsonb,
  add column if not exists background_image_public_id text,
  add column if not exists fcm_token text,
  add column if not exists is_typing_to text;

-- posts.likes / comments typed as ARRAY → keep an int counter OR array;
-- the existing schema uses users-typed arrays (likes text[]). Leave as text[].

-- messages: ensure reply / forward columns and conversation_id are present
alter table public.messages
  add column if not exists message_text text,
  add column if not exists conversation_id text,
  add column if not exists client_message_id text,
  add column if not exists reply_to_message_id uuid references public.messages(id) on delete set null,
  add column if not exists reply_to_text text,
  add column if not exists reply_to_message_type text,
  add column if not exists reply_to_sender_id uuid,
  add column if not exists reply_to_media_url text,
  add column if not exists deleted_for text[] not null default '{}',
  add column if not exists forwarded_from_user_id uuid,
  add column if not exists forwarded_from_user_name text,
  add column if not exists forwarded_from_user_avatar text,
  add column if not exists reply_to_story_id uuid,
  add column if not exists reply_to_story_author_id uuid,
  add column if not exists reply_to_story_type text,
  add column if not exists reply_to_story_media_url text,
  add column if not exists reply_to_story_text text,
  add column if not exists reply_to_story_bg_color text,
  add column if not exists reply_to_story_duration_seconds integer;

-- Helpful unique index that the chat_messages_service relies on for upsert.
create unique index if not exists messages_sender_client_id_uq
  on public.messages (sender_id, client_message_id)
  where client_message_id is not null;

-- ============================================================================
-- 6. RLS — open read on every existing/missing public table, restrict writes
--    to the row owner via auth.uid(). anon key reads public posts/users.
-- ============================================================================
alter table public.user_sticker_packs  enable row level security;
alter table public.reels_videos        enable row level security;
alter table public.fcm_tokens          enable row level security;
alter table public.comments_likes      enable row level security;

-- Re-enable on the legacy ones too, idempotent.
do $$
begin
  if exists (select 1 from pg_tables where schemaname='public' and tablename='posts') then
    alter table public.posts enable row level security;
  end if;
  if exists (select 1 from pg_tables where schemaname='public' and tablename='users') then
    alter table public.users enable row level security;
  end if;
end$$;

-- Helper: drop-if-exists then create the canonical policies.
drop policy if exists "Public posts are readable by everyone" on public.posts;
create policy "Public posts are readable by everyone"
  on public.posts for select using (true);

drop policy if exists "Authors manage their own posts" on public.posts;
create policy "Authors manage their own posts"
  on public.posts for all
  using  (author_id = auth.uid())
  with check (author_id = auth.uid());

drop policy if exists "Public user profiles are readable" on public.users;
create policy "Public user profiles are readable"
  on public.users for select using (true);

drop policy if exists "Users update their own row" on public.users;
create policy "Users update their own row"
  on public.users for update
  using  (id = auth.uid())
  with check (id = auth.uid());

-- user_sticker_packs: only owner can CRUD
drop policy if exists "Owner manages their sticker packs" on public.user_sticker_packs;
create policy "Owner manages their sticker packs"
  on public.user_sticker_packs for all
  using  (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "Public sticker packs are visible" on public.user_sticker_packs;
create policy "Public sticker packs are visible"
  on public.user_sticker_packs for select
  using (privacy_level = 'public'
         or owner_id = auth.uid()
         or privacy_level = 'friends'); -- friendship check left to view code

-- reels_videos: read-all, write-only service role
drop policy if exists "Reels videos are publicly readable" on public.reels_videos;
create policy "Reels videos are publicly readable"
  on public.reels_videos for select using (true);

-- fcm_tokens: only the owner can insert/update/select their own token
drop policy if exists "Owner manages their fcm tokens" on public.fcm_tokens;
create policy "Owner manages their fcm tokens"
  on public.fcm_tokens for all
  using  (user_id = auth.uid())
  with check (user_id = auth.uid());

-- comments_likes: only the owner can insert/delete, anyone can read counts
drop policy if exists "Comments likes are publicly readable" on public.comments_likes;
create policy "Comments likes are publicly readable"
  on public.comments_likes for select using (true);

drop policy if exists "Owner manages their comment likes" on public.comments_likes;
create policy "Owner manages their comment likes"
  on public.comments_likes for all
  using  (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================================
-- 7. RPCs that the Dart code calls (get_ranked_home_feed, toggle_post_share,
--    set_post_pinned, get_discover_people, toggle_story_reaction,
--    mark_story_viewed, get_my_stories_overview, get_story_viewers,
--    get_user_profile_post_ids, increment_post_link_share_count,
--    create_user_sticker_pack, get_group_fcm_tokens,
--    get_chats_with_last_message, get_balanced_reels_feed,
--    add_comment_with_mentions, get_profile_overview, get_profile_media_count,
--    get_mutual_groups)
--
-- Defined as SECURITY DEFINER + stable so PostgREST exposes them under
-- /rest/v1/rpc/<name>. They intentionally use ONLY existing columns to
-- avoid runtime "column does not exist" errors like the 404s in the report.
-- ============================================================================

-- Reusable helper: get a profile's post id+created_at cursor page
create or replace function public.get_user_profile_post_ids(
  p_user_id  uuid,
  p_limit    int default 15,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null,
  p_only_pinned boolean default false
) returns table(id uuid, created_at timestamptz, is_pinned boolean)
language sql stable security invoker as $$
  select p.id, p.created_at, p.is_pinned
  from public.posts p
  where p.author_id = p_user_id
    and (not p_only_pinned or p.is_pinned = true)
    and (p_before_created_at is null
         or (p.created_at, p.id) < (p_before_created_at, p_before_id))
  order by p.is_pinned desc, p.created_at desc, p.id desc
  limit greatest(coalesce(p_limit, 15), 1);
$$;

-- toggle_post_share: toggles the post_shares row and returns the new state.
create or replace function public.toggle_post_share(p_post_id uuid)
returns table(is_shared_by_me boolean, shares_count int) language plpgsql
security invoker as $$
declare
  v_uid uuid := auth.uid();
  v_exists boolean;
  v_count  int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select exists(
    select 1 from public.post_shares s
    where s.post_id = p_post_id and s.user_id = v_uid
  ) into v_exists;

  if v_exists then
    delete from public.post_shares
      where post_id = p_post_id and user_id = v_uid;
  else
    insert into public.post_shares(post_id, user_id)
      values (p_post_id, v_uid);
  end if;

  select count(*) into v_count from public.post_shares where post_id = p_post_id;
  return query select not v_exists, v_count;
end$$;

-- set_post_pinned: toggle pin on a post and maintain pinned_count.
create or replace function public.set_post_pinned(p_post_id uuid, p_pinned boolean)
returns void language plpgsql security invoker as $$
declare v_uid uuid := auth.uid(); v_count int;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  update public.posts
     set is_pinned = p_pinned, updated_at = now()
   where id = p_post_id and author_id = v_uid;
  if not found then raise exception 'post not found or not yours'; end if;

  select count(*) into v_count from public.posts where author_id = v_uid and is_pinned;
  update public.posts
     set pinned_count = v_count
   where author_id = v_uid and is_pinned;
end$$;

-- get_ranked_home_feed: returns recent posts visible to the caller.
create or replace function public.get_ranked_home_feed(p_limit int default 20)
returns table(id uuid, author_id uuid, text text,
              image_url text, video_url text, created_at timestamptz,
              likes bigint, comments bigint)
language sql stable security invoker as $$
  select p.id, p.author_id, p.text, p.image_url, p.video_url,
         p.created_at,
         coalesce(array_length(p.likes, 1), 0)::bigint as likes,
         coalesce(p.comments, 0)::bigint as comments
  from public.posts p
  order by p.is_pinned desc, p.created_at desc
  limit greatest(coalesce(p_limit, 20), 1);
$$;

-- get_discover_people: returns users that the caller is NOT following.
create or replace function public.get_discover_people(p_limit int default 20)
returns table(id uuid, name text, image_url text, tagline text) language sql
stable security invoker as $$
  select u.id, u.name, u.image_url, u.tagline
  from public.users u
  where u.id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
  order by u.last_seen desc nulls last
  limit greatest(coalesce(p_limit, 20), 1);
$$;

-- get_my_stories_overview / mark / react / viewers / get_chats_with_last_msg
create or replace function public.get_my_stories_overview()
returns table(id uuid, created_at timestamptz, view_count bigint)
language sql stable security invoker as $$
  select s.id, s.created_at,
         (select count(*) from public.story_views v where v.story_id = s.id)::bigint
  from public.stories s
  where s.author_id = auth.uid()
  order by s.created_at desc;
$$;

create or replace function public.mark_story_viewed(p_story_id uuid)
returns void language plpgsql security invoker as $$
begin
  if auth.uid() is null then return; end if;
  insert into public.story_views(story_id, viewer_id)
  values (p_story_id, auth.uid())
  on conflict (story_id, viewer_id) do nothing;
end$$;

create or replace function public.toggle_story_reaction(
  p_story_id uuid, p_reaction text
) returns boolean language plpgsql security invoker as $$
declare v_uid uuid := auth.uid(); v_exists boolean;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  select exists(
    select 1 from public.story_reactions
     where story_id = p_story_id and user_id = v_uid and reaction = p_reaction
  ) into v_exists;
  if v_exists then
    delete from public.story_reactions
      where story_id = p_story_id and user_id = v_uid and reaction = p_reaction;
    return false;
  else
    insert into public.story_reactions(story_id, user_id, reaction)
      values (p_story_id, v_uid, p_reaction);
    return true;
  end if;
end$$;

create or replace function public.get_story_viewers(p_story_id uuid)
returns table(user_id uuid, viewed_at timestamptz) language sql
stable security invoker as $$
  select v.viewer_id, v.viewed_at
  from public.story_views v
  where v.story_id = p_story_id
  order by v.viewed_at desc;
$$;

create or replace function public.get_chats_with_last_message(p_limit int default 50)
returns table(conversation_id text, last_message_id uuid, last_message_text text,
              last_message_at timestamptz) language sql stable security invoker as $$
  with last_per_conv as (
    select distinct on (m.conversation_id)
           m.conversation_id, m.id, m.message_text, m.created_at
    from public.messages m
    where m.sender_id = auth.uid() or m.receiver_id = auth.uid()
    order by m.conversation_id, m.created_at desc
  )
  select conversation_id, id, message_text, created_at
  from last_per_conv
  order by created_at desc
  limit greatest(coalesce(p_limit, 50), 1);
$$;

create or replace function public.get_balanced_reels_feed(p_limit int default 20)
returns table(id uuid, youtube_video_id text, title text, thumbnail_url text,
              published_at timestamptz) language sql stable security invoker as $$
  select r.id, r.youtube_video_id, r.title, r.thumbnail_url, r.published_at
  from public.reels_videos r
  order by r.published_at desc nulls last
  limit greatest(coalesce(p_limit, 20), 1);
$$;

create or replace function public.add_comment_with_mentions(
  p_post_id uuid, p_text text, p_mentions jsonb default '[]'::jsonb
) returns uuid language plpgsql security invoker as $$
declare v_uid uuid := auth.uid(); v_id uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  insert into public.comments(post_id, author_id, text)
  values (p_post_id, v_uid, p_text)
  returning id into v_id;
  if jsonb_array_length(p_mentions) > 0 then
    insert into public.comment_mentions(comment_id, mentioned_user_id, start_index, end_index)
    select v_id,
           (m->>'mentioned_user_id')::uuid,
           (m->>'start_index')::int,
           (m->>'end_index')::int
    from jsonb_array_elements(p_mentions) m;
  end if;
  return v_id;
end$$;

create or replace function public.get_profile_overview(p_user_id uuid)
returns table(
  user_id uuid, name text, image_url text, tagline text,
  posts_count bigint, followers_count bigint, following_count bigint
) language sql stable security invoker as $$
  select u.id, u.name, u.image_url, u.tagline,
         (select count(*) from public.posts p where p.author_id = u.id)::bigint,
         (select count(*) from public.follows f where f.following_id = u.id)::bigint,
         (select count(*) from public.follows f where f.follower_id = u.id)::bigint
  from public.users u
  where u.id = p_user_id;
$$;

create or replace function public.get_profile_media_count(p_user_id uuid)
returns bigint language sql stable security invoker as $$
  select count(*)
  from public.posts p
  where p.author_id = p_user_id
    and (p.image_url is not null or p.video_url is not null);
$$;

create or replace function public.get_mutual_groups(p_user_id uuid)
returns table(group_id uuid, name text, avatar_url text) language sql
stable security invoker as $$
  select g.id, g.name, g.avatar_url
  from public.groups g
  where exists (
    select 1 from public.group_members m1
    where m1.group_id = g.id and m1.user_id = p_user_id
  ) and exists (
    select 1 from public.group_members m2
    where m2.group_id = g.id and m2.user_id = auth.uid()
  );
$$;

create or replace function public.create_user_sticker_pack(
  p_title text, p_cover text, p_count int, p_size_bytes bigint,
  p_has_animated boolean default false, p_privacy text default 'private'
) returns uuid language plpgsql security invoker as $$
declare v_id uuid; v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  insert into public.user_sticker_packs(
    owner_id, title, cover_url, sticker_count, total_size_bytes,
    has_animated, privacy_level)
  values (v_uid, p_title, p_cover, p_count, p_size_bytes, p_has_animated, p_privacy)
  returning id into v_id;
  return v_id;
end$$;

create or replace function public.get_group_fcm_tokens(p_group_id uuid)
returns table(user_id uuid, token text) language sql stable security invoker as $$
  select ft.user_id, ft.token
  from public.fcm_tokens ft
  join public.group_members gm on gm.user_id = ft.user_id
  where gm.group_id = p_group_id and gm.membership_status = 'active';
$$;

create or replace function public.increment_post_link_share_count(p_post_id uuid)
returns int language plpgsql security invoker as $$
declare v_count int;
begin
  update public.posts
     set link_share_count = coalesce(link_share_count, 0) + 1, updated_at = now()
   where id = p_post_id
   returning link_share_count into v_count;
  return coalesce(v_count, 0);
end$$;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
