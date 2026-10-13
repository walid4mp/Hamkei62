-- =====================================================================
-- Hamkei62 — FINAL CONSOLIDATED MIGRATION (consolidated 2026-10-13)
-- Idempotent. Every step uses IF NOT EXISTS / CREATE OR REPLACE.
-- Targets the exact gaps surfaced in the 14 screenshots.
-- =====================================================================

------------------------------------------------------------------
-- 0) Cache reload — flushes PostgREST schema cache, so it
--    recognises the new action_type column and removes PGRST204
--    "could not find action_type" errors in typing_status RPC.
------------------------------------------------------------------
SELECT pg_notify('pgrst', 'reload schema');

------------------------------------------------------------------
-- 1) typing_status + group_typing_status (build-information)
-- =====================================================================
ALTER TABLE public.typing_status
  ADD COLUMN IF NOT EXISTS action_type text NOT NULL DEFAULT 'none';
ALTER TABLE public.group_typing_status
  ADD COLUMN IF NOT EXISTS action_type text NOT NULL DEFAULT 'none';

DO $ty$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='typing_status_pkey') THEN
    ALTER TABLE public.typing_status
      ADD CONSTRAINT typing_status_pkey PRIMARY KEY (chat_id, user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='group_typing_status_pkey') THEN
    ALTER TABLE public.group_typing_status
      ADD CONSTRAINT group_typing_status_pkey PRIMARY KEY (group_id, user_id);
  END IF;
END $ty$;

------------------------------------------------------------------
-- 2) notification_preferences (missing table)
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id          uuid        PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  posts_enabled    boolean DEFAULT true,
  messages_enabled boolean DEFAULT true,
  stories_enabled  boolean DEFAULT true,
  groups_enabled   boolean DEFAULT true,
  updated_at       timestamptz DEFAULT now()
);
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

------------------------------------------------------------------
-- 3) Missing columns for ALL tables the Flutter client references
--    via lib/core/utilities/supabase_constants.dart.
--    Same text-by-text shape as the REST queries.
-- =====================================================================
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS conversation_id             text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS client_message_id           uuid;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS reply_to_message_id         uuid;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS reply_to_text                text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS reply_to_message_type        text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS reply_to_sender_id           uuid;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS reply_to_media_url           text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS reaction                     text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS caption                      text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS duration_seconds             integer;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS file_name                    text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS file_size_bytes              bigint;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS file_url                     text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS voice_url                    text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS video_url                    text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS image_url                    text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS image_public_id              text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS video_public_id              text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS voice_public_id              text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS file_public_id               text;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS deleted_for                  text[];
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS forwarded_from_user_id       uuid;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS forwarded_from_message_id    uuid;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS reply_to_story_id            uuid;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS reply_to_story_author_id     uuid;
ALTER TABLE public.messages             ADD COLUMN IF NOT EXISTS is_edited                   boolean DEFAULT false;

ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS is_typing_to                 uuid;
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS tagline                      text;
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS is_tagline_hidden           boolean DEFAULT false;
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS theme                        text;
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS fcm_token                    text;
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS image_public_id              text;
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS background_image_url         text;
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS background_image_public_id   text;
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS presence_privacy             text DEFAULT 'friends';
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS presence_visible_to          text[];
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS social_links                 jsonb;
ALTER TABLE public.users                ADD COLUMN IF NOT EXISTS last_seen                    timestamptz;

ALTER TABLE public.user_presence        ADD COLUMN IF NOT EXISTS last_seen                    timestamptz;

ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS media_width                  integer;
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS media_height                 integer;
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS file_url                     text;
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS file_public_id               text;
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS shared_post_id               uuid;
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS shared_reel_id               uuid;
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS is_pinned                   boolean DEFAULT false;
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS privacy_type                 text DEFAULT 'public';
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS original_post                jsonb;
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS likes                        integer DEFAULT 0;
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS comments                     integer DEFAULT 0;
ALTER TABLE public.posts                ADD COLUMN IF NOT EXISTS original_post_relation       jsonb;

ALTER TABLE public.stories              ADD COLUMN IF NOT EXISTS content_text                 text;
ALTER TABLE public.stories              ADD COLUMN IF NOT EXISTS background_color             text;
ALTER TABLE public.stories              ADD COLUMN IF NOT EXISTS caption                      text;
ALTER TABLE public.stories              ADD COLUMN IF NOT EXISTS image_public_id              text;
ALTER TABLE public.stories              ADD COLUMN IF NOT EXISTS video_public_id              text;
ALTER TABLE public.stories              ADD COLUMN IF NOT EXISTS video_duration_seconds       integer;
ALTER TABLE public.stories              ADD COLUMN IF NOT EXISTS privacy_type                 text DEFAULT 'public';

ALTER TABLE public.stickers             ADD COLUMN IF NOT EXISTS image_url                    text;
ALTER TABLE public.stickers             ADD COLUMN IF NOT EXISTS is_animated                 boolean DEFAULT false;
ALTER TABLE public.stickers             ADD COLUMN IF NOT EXISTS size_bytes                   bigint;
ALTER TABLE public.stickers             ADD COLUMN IF NOT EXISTS format                       text;
ALTER TABLE public.stickers             ADD COLUMN IF NOT EXISTS sort_order                   integer DEFAULT 0;

ALTER TABLE public.sticker_packs        ADD COLUMN IF NOT EXISTS cover_url                    text;
ALTER TABLE public.sticker_packs        ADD COLUMN IF NOT EXISTS description                  text;
ALTER TABLE public.sticker_packs        ADD COLUMN IF NOT EXISTS sort_order                   integer DEFAULT 0;
ALTER TABLE public.sticker_packs        ADD COLUMN IF NOT EXISTS has_animated                 boolean DEFAULT false;
ALTER TABLE public.sticker_packs        ADD COLUMN IF NOT EXISTS sticker_count                integer DEFAULT 0;
ALTER TABLE public.sticker_packs        ADD COLUMN IF NOT EXISTS total_size_bytes             bigint DEFAULT 0;
ALTER TABLE public.sticker_packs        ADD COLUMN IF NOT EXISTS privacy_level                text DEFAULT 'private';

ALTER TABLE public.groups               ADD COLUMN IF NOT EXISTS description                  text;
ALTER TABLE public.groups               ADD COLUMN IF NOT EXISTS cover_image_url              text;
ALTER TABLE public.groups               ADD COLUMN IF NOT EXISTS privacy_level                text DEFAULT 'public';
ALTER TABLE public.groups               ADD COLUMN IF NOT EXISTS invite_hash                  text;
ALTER TABLE public.groups               ADD COLUMN IF NOT EXISTS invite_expires_at            timestamptz;
ALTER TABLE public.groups               ADD COLUMN IF NOT EXISTS invite_join_count            integer DEFAULT 0;

ALTER TABLE public.post_allowed_viewers ADD COLUMN IF NOT EXISTS post_id uuid;
ALTER TABLE public.post_allowed_viewers ADD COLUMN IF NOT EXISTS user_id uuid;
ALTER TABLE public.story_allowed_viewers ADD COLUMN IF NOT EXISTS story_id uuid;
ALTER TABLE public.story_allowed_viewers ADD COLUMN IF NOT EXISTS user_id uuid;

ALTER TABLE public.chat_mutes           ADD COLUMN IF NOT EXISTS peer_id                      uuid;
ALTER TABLE public.chat_mutes           ADD COLUMN IF NOT EXISTS is_muted                     boolean DEFAULT false;

ALTER TABLE public.calls                ADD COLUMN IF NOT EXISTS caller_name                  text;
ALTER TABLE public.calls                ADD COLUMN IF NOT EXISTS caller_avatar                text;
ALTER TABLE public.calls                ADD COLUMN IF NOT EXISTS receiver_name                text;
ALTER TABLE public.calls                ADD COLUMN IF NOT EXISTS receiver_avatar              text;
ALTER TABLE public.calls                ADD COLUMN IF NOT EXISTS type                         text DEFAULT 'audio';

ALTER TABLE public.notifications        ADD COLUMN IF NOT EXISTS recipient_id                 uuid;
ALTER TABLE public.notifications        ADD COLUMN IF NOT EXISTS sender_id                    uuid;
ALTER TABLE public.notifications        ADD COLUMN IF NOT EXISTS kind                         text DEFAULT 'post';
ALTER TABLE public.notifications        ADD COLUMN IF NOT EXISTS post_id                      uuid;
ALTER TABLE public.notifications        ADD COLUMN IF NOT EXISTS comment_id                   uuid;
ALTER TABLE public.notifications        ADD COLUMN IF NOT EXISTS is_read                      boolean DEFAULT false;

ALTER TABLE public.comments             ADD COLUMN IF NOT EXISTS parent_comment_id            uuid;
ALTER TABLE public.comments             ADD COLUMN IF NOT EXISTS deleted_for                  text[];
ALTER TABLE public.comments             ADD COLUMN IF NOT EXISTS like_count                   integer DEFAULT 0;
ALTER TABLE public.comments             ADD COLUMN IF NOT EXISTS image_url                    text;
ALTER TABLE public.comments             ADD COLUMN IF NOT EXISTS image_public_id              text;
ALTER TABLE public.comments             ADD COLUMN IF NOT EXISTS video_url                    text;
ALTER TABLE public.comments             ADD COLUMN IF NOT EXISTS voice_url                    text;
ALTER TABLE public.comments             ADD COLUMN IF NOT EXISTS file_url                     text;
ALTER TABLE public.comments             ADD COLUMN IF NOT EXISTS file_name                    text;
ALTER TABLE public.comments             ADD COLUMN IF NOT EXISTS file_size_bytes              bigint;

ALTER TABLE public.fcm_tokens           ADD COLUMN IF NOT EXISTS user_id                      uuid;
ALTER TABLE public.fcm_tokens           ADD COLUMN IF NOT EXISTS token                        text;
ALTER TABLE public.fcm_tokens           ADD COLUMN IF NOT EXISTS platform                     text DEFAULT 'web';
ALTER TABLE public.fcm_tokens           ADD COLUMN IF NOT EXISTS updated_at                   timestamptz DEFAULT now();

ALTER TABLE public.message_reactions    ADD COLUMN IF NOT EXISTS message_id                   uuid;
ALTER TABLE public.message_reactions    ADD COLUMN IF NOT EXISTS conversation_id              text;
ALTER TABLE public.message_reactions    ADD COLUMN IF NOT EXISTS user_id                      uuid;
ALTER TABLE public.message_reactions    ADD COLUMN IF NOT EXISTS reaction                     text;

------------------------------------------------------------------
-- 4) Foreign keys (idempotent via DO/IF-NOT-EXISTS guards)
-- =====================================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='pav_post_fk') THEN
    ALTER TABLE public.post_allowed_viewers
      ADD CONSTRAINT pav_post_fk FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='pav_user_fk') THEN
    ALTER TABLE public.post_allowed_viewers
      ADD CONSTRAINT pav_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='sav_story_fk') THEN
    ALTER TABLE public.story_allowed_viewers
      ADD CONSTRAINT sav_story_fk FOREIGN KEY (story_id) REFERENCES public.stories(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='sav_user_fk') THEN
    ALTER TABLE public.story_allowed_viewers
      ADD CONSTRAINT sav_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='cm_owner_fk') THEN
    ALTER TABLE public.chat_mutes
      ADD CONSTRAINT cm_owner_fk FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='cm_peer_fk') THEN
    ALTER TABLE public.chat_mutes
      ADD CONSTRAINT cm_peer_fk FOREIGN KEY (peer_id) REFERENCES public.users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='notif_recipient_fk') THEN
    ALTER TABLE public.notifications
      ADD CONSTRAINT notif_recipient_fk FOREIGN KEY (recipient_id) REFERENCES public.users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='notif_sender_fk') THEN
    ALTER TABLE public.notifications
      ADD CONSTRAINT notif_sender_fk FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='mr_msg_fk') THEN
    ALTER TABLE public.message_reactions
      ADD CONSTRAINT mr_msg_fk FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='mr_user_fk') THEN
    ALTER TABLE public.message_reactions
      ADD CONSTRAINT mr_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
  END IF;
END $$;

------------------------------------------------------------------
-- 5) RLS — drop-and-recreate policies cleanly
-- =====================================================================
ALTER TABLE public.typing_status          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_typing_status    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sticker_pack_shares     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_message_mentions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_allowed_viewers   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_allowed_viewers  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_mutes             ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS typing_status_select       ON public.typing_status;
DROP POLICY IF EXISTS typing_status_write       ON public.typing_status;
DROP POLICY IF EXISTS gts_select                ON public.group_typing_status;
DROP POLICY IF EXISTS gts_write                 ON public.group_typing_status;
DROP POLICY IF EXISTS sps_select                ON public.sticker_pack_shares;
DROP POLICY IF EXISTS sps_write                 ON public.sticker_pack_shares;
DROP POLICY IF EXISTS gmr_select                ON public.group_message_reactions;
DROP POLICY IF EXISTS gmr_write                 ON public.group_message_reactions;
DROP POLICY IF EXISTS gmm_select                ON public.group_message_mentions;
DROP POLICY IF EXISTS gmm_write                 ON public.group_message_mentions;
DROP POLICY IF EXISTS mr_select                 ON public.message_reactions;
DROP POLICY IF EXISTS mr_write                  ON public.message_reactions;
DROP POLICY IF EXISTS pav_select                ON public.post_allowed_viewers;
DROP POLICY IF EXISTS pav_write                 ON public.post_allowed_viewers;
DROP POLICY IF EXISTS sav_select                ON public.story_allowed_viewers;
DROP POLICY IF EXISTS sav_write                 ON public.story_allowed_viewers;
DROP POLICY IF EXISTS cm_select                 ON public.chat_mutes;
DROP POLICY IF EXISTS cm_write                  ON public.chat_mutes;

CREATE POLICY typing_status_select ON public.typing_status          FOR SELECT TO authenticated USING (true);
CREATE POLICY typing_status_write ON public.typing_status          FOR ALL    TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY gts_select          ON public.group_typing_status    FOR SELECT TO authenticated USING (true);
CREATE POLICY gts_write           ON public.group_typing_status    FOR ALL    TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY sps_select          ON public.sticker_pack_shares     FOR SELECT TO authenticated USING (true);
CREATE POLICY sps_write           ON public.sticker_pack_shares     FOR ALL    TO authenticated
  USING (shared_with_user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.sticker_packs p WHERE p.id = pack_id AND p.owner_id = auth.uid())) WITH CHECK (true);
CREATE POLICY gmr_select          ON public.group_message_reactions FOR SELECT TO authenticated USING (true);
CREATE POLICY gmr_write           ON public.group_message_reactions FOR ALL    TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY gmm_select          ON public.group_message_mentions  FOR SELECT TO authenticated USING (true);
CREATE POLICY gmm_write           ON public.group_message_mentions  FOR ALL    TO authenticated
  USING (mentioned_user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.group_members gm WHERE gm.group_id = group_message_mentions.group_id AND gm.user_id = auth.uid())) WITH CHECK (true);
CREATE POLICY mr_select           ON public.message_reactions       FOR SELECT TO authenticated USING (true);
CREATE POLICY mr_write            ON public.message_reactions       FOR ALL    TO authenticated
  USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.messages m WHERE m.id = message_reactions.message_id AND (m.sender_id = auth.uid() OR m.receiver_id = auth.uid())))
  WITH CHECK (user_id = auth.uid());
CREATE POLICY pav_select          ON public.post_allowed_viewers   FOR SELECT TO authenticated USING (true);
CREATE POLICY pav_write           ON public.post_allowed_viewers   FOR ALL    TO authenticated
  USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_allowed_viewers.post_id AND p.author_id = auth.uid())) WITH CHECK (true);
CREATE POLICY sav_select          ON public.story_allowed_viewers  FOR SELECT TO authenticated USING (true);
CREATE POLICY sav_write           ON public.story_allowed_viewers  FOR ALL    TO authenticated
  USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.stories s WHERE s.id = story_allowed_viewers.story_id AND s.author_id = auth.uid())) WITH CHECK (true);
CREATE POLICY cm_select           ON public.chat_mutes             FOR SELECT TO authenticated USING (owner_id = auth.uid() OR peer_id = auth.uid());
CREATE POLICY cm_write            ON public.chat_mutes             FOR ALL    TO authenticated USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.typing_status, public.group_typing_status,
  public.sticker_pack_shares, public.group_message_reactions,
  public.group_message_mentions, public.message_reactions,
  public.post_allowed_viewers, public.story_allowed_viewers,
  public.chat_mutes, public.notification_preferences
TO authenticated;
GRANT SELECT ON
  public.typing_status, public.users, public.posts
TO anon;

------------------------------------------------------------------
-- 6) RPCs: drop duplicate overloaded versions; keep signatures
--    that match the Dart call-sites in lib/ (text/uuid mix).
-- =====================================================================
DROP FUNCTION IF EXISTS public.search_people(text,text,integer,integer);
DROP FUNCTION IF EXISTS public.search_people(text);
DROP FUNCTION IF EXISTS public.search_people(integer,integer,text,text);
DROP FUNCTION IF EXISTS public.get_discover_people(text,integer,integer);

CREATE OR REPLACE FUNCTION public.search_people(
  p_query   text, p_user_id text, p_limit integer, p_offset integer)
RETURNS TABLE(id text, name text, username text, image_url text, tagline text, last_seen timestamptz, friendship_status text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='public' AS $f$
  SELECT u.id::text, u.name, u.username, u.image_url, u.tagline, u.last_seen,
         CASE WHEN f.follower_id IS NULL THEN 'none' ELSE 'friend' END
  FROM public.users u
  LEFT JOIN public.follows f ON f.follower_id::text = p_user_id AND f.following_id = u.id
  WHERE u.id::text <> p_user_id
    AND (u.name ILIKE '%'||p_query||'%' OR u.username ILIKE '%'||p_query||'%')
  ORDER BY u.name
  LIMIT p_limit OFFSET p_offset;
$f$;

CREATE OR REPLACE FUNCTION public.get_discover_people(
  p_user_id text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0)
RETURNS TABLE(id text, name text, username text, image_url text, tagline text, last_seen timestamptz, friendship_status text, mutual_count int, posts_count int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='public' AS $f$
  SELECT u.id::text, u.name, u.username, u.image_url, u.tagline, u.last_seen,
         'none'::text friendship_status,
         0::int as mutual_count,
         COALESCE((SELECT count(*) FROM public.posts p WHERE p.author_id = u.id),0)::int as posts_count
  FROM public.users u
  WHERE u.id::text <> p_user_id
  ORDER BY u.created_at DESC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
$f$;

CREATE OR REPLACE FUNCTION public.mark_messages_read(other_user_id text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='public' AS $f$
  UPDATE public.messages m SET is_read = true
  WHERE m.sender_id::text = other_user_id AND m.receiver_id::text = auth.uid()::text
    AND COALESCE(m.is_read, false) = false;
$f$;

GRANT EXECUTE ON FUNCTION public.search_people(text,text,integer,integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_discover_people(text,integer,integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_read(text)            TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_chats_with_last_message(text,text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_profile_overview(text,text)    TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_profile_media_count(text)      TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_profile_mutuals(text,text)     TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_friends(text,text,integer,integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_reels(text,integer,integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_ranked_home_feed(text,integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_user_profile_post_ids(text,integer,boolean,text,text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_messages_with_user(text)       TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_posts(text,text,integer,integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_my_groups(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_groups(text,text,integer,integer) TO authenticated, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, anon;

------------------------------------------------------------------
-- 7) Realtime publication + replica identity
-- =====================================================================
DO $rt$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
EXCEPTION WHEN duplicate_object THEN NULL; WHEN OTHERS THEN NULL; END $rt$;
ALTER TABLE public.users REPLICA IDENTITY FULL;

CREATE INDEX IF NOT EXISTS users_id_text_idx            ON public.users (id);
CREATE INDEX IF NOT EXISTS messages_conversation_idx     ON public.messages (conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS messages_sender_receiver_idx  ON public.messages (sender_id, receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS posts_author_created_idx      ON public.posts (author_id, created_at DESC);

------------------------------------------------------------------
-- 8) Seed: a hello post for 'jegdhd' so the profile isn't empty
--    (idempotent via existing-row check).
-- =====================================================================
INSERT INTO public.posts (author_id, text, privacy_type, created_at)
SELECT id, 'أهلاً! هذا أول منشور لـjegdhd على SOCIAL MATE 🎉', 'public', now()
FROM public.users WHERE id::text = 'c8f5b092-caa5-484b-8709-3cc2a2ce0d55'
  AND NOT EXISTS (SELECT 1 FROM public.posts WHERE author_id::text='c8f5b092-caa5-484b-8709-3cc2a2ce0d55');

SELECT pg_notify('pgrst', 'reload schema');
