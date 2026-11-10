-- SocialPlus — Supabase schema v1 (PostgreSQL 15)
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- ========= PROFILES =========
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 30),
  full_name text,
  avatar_url text,
  cover_url text,
  bio text,
  phone text,
  website text,
  is_verified boolean not null default false,
  is_admin boolean not null default false,
  is_banned boolean not null default false,
  coins integer not null default 0 check (coins >= 0),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'phone'
  ) on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ========= FOLLOWS =========
create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

-- ========= POSTS =========
create table if not exists public.posts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null default '',
  media_urls text[] not null default '{}',
  media_type text not null default 'text' check (media_type in ('text','image','video')),
  location text,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists posts_user_idx on public.posts (user_id, created_at desc);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  is_toxic boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.saved_posts (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- ========= STORIES =========
create table if not exists public.stories (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_url text,
  caption text,
  music text,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  created_at timestamptz not null default now()
);

create table if not exists public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

-- ========= REELS =========
create table if not exists public.reels (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  video_url text not null,
  caption text,
  sound_name text,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  share_count integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.reel_likes (
  reel_id uuid not null references public.reels(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reel_id, user_id)
);

-- ========= CHAT =========
create table if not exists public.conversations (
  id uuid primary key default uuid_generate_v4(),
  is_group boolean not null default false,
  title text,
  last_message text,
  updated_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default uuid_generate_v4(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  content text not null default '',
  kind text not null default 'text' check (kind in ('text','image','video','file','voice','gift')),
  media_url text,
  reply_to uuid references public.messages(id) on delete set null,
  edited boolean not null default false,
  deleted boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists messages_conv_idx on public.messages (conversation_id, created_at);

-- ========= NOTIFICATIONS =========
create table if not exists public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('like','comment','follow','message','live','system')),
  entity_id uuid,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ========= LIVE + GIFTS =========
create table if not exists public.streams (
  id uuid primary key default uuid_generate_v4(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default 'بث مباشر',
  viewer_count integer not null default 0,
  coin_count integer not null default 0,
  status text not null default 'live' check (status in ('live','ended')),
  created_at timestamptz not null default now()
);

create table if not exists public.gifts (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  icon text not null default '🎁',
  price integer not null check (price > 0)
);

insert into public.gifts (name, icon, price) values
  ('وردة', '🌹', 5), ('قلب', '❤️', 10), ('دبدوب', '🧸', 25),
  ('ماسة', '💎', 100), ('تاج', '👑', 250), ('صاروخ', '🚀', 500)
on conflict do nothing;

create table if not exists public.gifts_sent (
  id uuid primary key default uuid_generate_v4(),
  gift_id uuid not null references public.gifts(id),
  sender_id uuid not null references public.profiles(id),
  receiver_id uuid not null references public.profiles(id),
  stream_id uuid references public.streams(id),
  quantity integer not null default 1 check (quantity > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.coin_transactions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount integer not null,
  reason text not null check (reason in ('purchase','gift_sent','gift_received','withdrawal','reward','transfer')),
  meta jsonb,
  created_at timestamptz not null default now()
);

-- ========= MODERATION / ADMIN =========
create table if not exists public.reports (
  id uuid primary key default uuid_generate_v4(),
  reporter_id uuid not null references public.profiles(id),
  entity_type text not null check (entity_type in ('post','user','comment','message')),
  entity_id uuid not null,
  reason text not null,
  status text not null default 'open' check (status in ('open','resolved','rejected')),
  created_at timestamptz not null default now()
);

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

create table if not exists public.ads (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  media_url text,
  target_url text,
  active boolean not null default true,
  impressions integer not null default 0,
  clicks integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.rate_limits (
  client_id text not null,
  action text not null,
  window_start timestamptz not null default now(),
  count integer not null default 1,
  primary key (client_id, action, window_start)
);

-- ========= FUNCTIONS =========
create or replace function public.toggle_post_like(p_post_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'auth required'; end if;
  if exists (select 1 from post_likes where post_id = p_post_id and user_id = v_user) then
    delete from post_likes where post_id = p_post_id and user_id = v_user;
    update posts set like_count = greatest(like_count - 1, 0) where id = p_post_id;
  else
    insert into post_likes (post_id, user_id) values (p_post_id, v_user);
    update posts set like_count = like_count + 1 where id = p_post_id;
  end if;
end $$;

create or replace function public.buy_coins(p_amount integer)
returns integer language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'auth required'; end if;
  if p_amount is null or p_amount <= 0 or p_amount > 10000 then raise exception 'invalid amount'; end if;
  update profiles set coins = coins + p_amount where id = v_user;
  insert into coin_transactions (user_id, amount, reason) values (v_user, p_amount, 'purchase');
  return (select coins from profiles where id = v_user);
end $$;

create or replace function public.send_gift(p_gift_id uuid, p_receiver uuid, p_stream_id uuid default null, p_qty integer default 1)
returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_price integer; v_total integer;
begin
  if v_user is null then raise exception 'auth required'; end if;
  select price into v_price from gifts where id = p_gift_id;
  if v_price is null then raise exception 'gift not found'; end if;
  v_total := v_price * p_qty;
  update profiles set coins = coins - v_total
    where id = v_user and coins >= v_total;
  if not found then raise exception 'insufficient coins'; end if;
  update profiles set coins = coins + v_total where id = p_receiver;
  insert into gifts_sent (gift_id, sender_id, receiver_id, stream_id, quantity)
    values (p_gift_id, v_user, p_receiver, p_stream_id, p_qty);
  insert into coin_transactions (user_id, amount, reason, meta) values
    (v_user, -v_total, 'gift_sent', jsonb_build_object('gift', p_gift_id)),
    (p_receiver, v_total, 'gift_received', jsonb_build_object('gift', p_gift_id));
end $$;

-- ========= RLS =========
alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.saved_posts enable row level security;
alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.reels enable row level security;
alter table public.reel_likes enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.streams enable row level security;
alter table public.gifts enable row level security;
alter table public.gifts_sent enable row level security;
alter table public.coin_transactions enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
alter table public.ads enable row level security;
alter table public.rate_limits enable row level security;

create policy "profiles_read" on public.profiles for select using (true);
create policy "profile_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id and is_admin = (select is_admin from profiles where id = auth.uid()));

create policy "follows_read" on public.follows for select using (true);
create policy "follows_write" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete" on public.follows for delete using (auth.uid() = follower_id);

create policy "posts_read" on public.posts for select using (true);
create policy "posts_insert" on public.posts for insert with check (auth.uid() = user_id);
create policy "posts_update_own" on public.posts for update using (auth.uid() = user_id);
create policy "posts_delete_own" on public.posts for delete using (auth.uid() = user_id);

create policy "likes_read" on public.post_likes for select using (true);
create policy "likes_insert" on public.post_likes for insert with check (auth.uid() = user_id);
create policy "likes_delete" on public.post_likes for delete using (auth.uid() = user_id);

create policy "comments_read" on public.comments for select using (true);
create policy "comments_insert" on public.comments for insert with check (auth.uid() = user_id);
create policy "comments_delete_own" on public.comments for delete using (auth.uid() = user_id);

create policy "saved_read" on public.saved_posts for select using (auth.uid() = user_id);
create policy "saved_insert" on public.saved_posts for insert with check (auth.uid() = user_id);
create policy "saved_delete" on public.saved_posts for delete using (auth.uid() = user_id);

create policy "stories_read" on public.stories for select using (true);
create policy "stories_insert" on public.stories for insert with check (auth.uid() = user_id);
create policy "stories_delete_own" on public.stories for delete using (auth.uid() = user_id);

create policy "story_views_write" on public.story_views for insert with check (auth.uid() = viewer_id);
create policy "story_views_read" on public.story_views for select using (true);

create policy "reels_read" on public.reels for select using (true);
create policy "reels_insert" on public.reels for insert with check (auth.uid() = user_id);
create policy "reels_delete_own" on public.reels for delete using (auth.uid() = user_id);

create policy "reel_likes_rw" on public.reel_likes for select using (true);
create policy "reel_likes_insert" on public.reel_likes for insert with check (auth.uid() = user_id);
create policy "reel_likes_delete" on public.reel_likes for delete using (auth.uid() = user_id);

create policy "conv_read_member" on public.conversations for select using (
  exists (select 1 from conversation_members m where m.conversation_id = id and m.user_id = auth.uid())
);
create policy "conv_insert" on public.conversations for insert with check (true);
create policy "conv_update_member" on public.conversations for update using (
  exists (select 1 from conversation_members m where m.conversation_id = id and m.user_id = auth.uid())
);

create policy "members_read" on public.conversation_members for select using (
  exists (select 1 from conversation_members m2 where m2.conversation_id = conversation_id and m2.user_id = auth.uid())
);
create policy "members_insert" on public.conversation_members for insert with check (auth.uid() = user_id);

create policy "messages_read_member" on public.messages for select using (
  exists (select 1 from conversation_members m where m.conversation_id = conversation_id and m.user_id = auth.uid())
);
create policy "messages_insert" on public.messages for insert with check (auth.uid() = sender_id);
create policy "messages_update_own" on public.messages for update using (auth.uid() = sender_id);
create policy "messages_delete_own" on public.messages for delete using (auth.uid() = sender_id);

create policy "notif_read_own" on public.notifications for select using (auth.uid() = user_id);
create policy "notif_update_own" on public.notifications for update using (auth.uid() = user_id);

create policy "streams_read" on public.streams for select using (true);
create policy "streams_insert" on public.streams for insert with check (auth.uid() = host_id);
create policy "streams_update_host" on public.streams for update using (auth.uid() = host_id);

create policy "gifts_read" on public.gifts for select using (true);
create policy "gifts_sent_read_own" on public.gifts_sent for select using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "coin_tx_read_own" on public.coin_transactions for select using (auth.uid() = user_id);

create policy "reports_insert" on public.reports for insert with check (auth.uid() = reporter_id);
create policy "reports_read_admin" on public.reports for select using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin)
);
create policy "reports_update_admin" on public.reports for update using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin)
);

create policy "blocks_rw" on public.blocks for select using (auth.uid() = blocker_id);
create policy "blocks_insert" on public.blocks for insert with check (auth.uid() = blocker_id);
create policy "blocks_delete" on public.blocks for delete using (auth.uid() = blocker_id);

create policy "ads_read" on public.ads for select using (active);
create policy "ads_admin" on public.ads for all using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin)
) with check (
  exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin)
);

create policy "rate_limits_insert" on public.rate_limits for insert with check (true);
