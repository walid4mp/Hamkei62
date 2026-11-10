-- SocialPlus v1.2 — privacy, groups, reactions, live, admin

alter table public.profiles
  add column if not exists is_private boolean not null default false,
  add column if not exists allow_messages text not null default 'everyone' check (allow_messages in ('everyone','following','nobody')),
  add column if not exists show_online boolean not null default true,
  add column if not exists show_last_seen boolean not null default true,
  add column if not exists muted_ids uuid[] not null default '{}',
  add column if not exists push_token text;

alter table public.follows add column if not exists status text not null default 'accepted' check (status in ('accepted','pending'));

create table if not exists public.mutes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  muted_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, muted_id)
);

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create table if not exists public.story_reactions (
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);

create table if not exists public.reel_views (
  reel_id uuid not null references public.reels(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reel_id, viewer_id)
);

alter table public.streams
  add column if not exists ended_at timestamptz,
  add column if not exists peak_viewers integer not null default 0;

create table if not exists public.live_messages (
  id uuid primary key default uuid_generate_v4(),
  stream_id uuid not null references public.streams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_log (
  id uuid primary key default uuid_generate_v4(),
  admin_id uuid not null references public.profiles(id),
  action text not null,
  target text,
  created_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

-- منع الإشعارات المكررة
create unique index if not exists notif_dedup on public.notifications (user_id, actor_id, kind, coalesce(entity_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- فهارس الأداء
create index if not exists follows_following_idx on public.follows (following_id);
create index if not exists notif_user_idx on public.notifications (user_id, created_at desc);
create index if not exists post_likes_post_idx on public.post_likes (post_id);
create index if not exists comments_post_idx on public.comments (post_id, created_at);
create index if not exists reels_created_idx on public.reels (created_at desc);
create index if not exists gifts_recv_idx on public.gifts_sent (receiver_id, created_at desc);
create index if not exists live_msg_stream_idx on public.live_messages (stream_id, created_at);

-- منع تعديل الأرصدة والصلاحيات مباشرة من العميل
drop policy if exists "profile_update_own" on public.profiles;
create policy "profile_update_own" on public.profiles for update
  using (auth.uid() = id and is_banned = false)
  with check (
    auth.uid() = id
    and coins = (select coins from profiles where id = auth.uid())
    and is_admin = (select is_admin from profiles where id = auth.uid())
    and is_verified = (select is_verified from profiles where id = auth.uid())
    and is_banned = (select is_banned from profiles where id = auth.uid())
  );

-- الهدايا عبر RPC فقط (لا إدراج مباشر)
drop policy if exists "gifts_sent_read_own" on public.gifts_sent;
create policy "gifts_sent_read_own" on public.gifts_sent for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id
         or exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin));

-- رسالة خاصة تحترم الحظر والخصوصية
create or replace function public.can_message(p_from uuid, p_to uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (select 1 from blocks b where (b.blocker_id = p_to and b.blocked_id = p_from) or (b.blocker_id = p_from and b.blocked_id = p_to))
  and not exists (select 1 from profiles t where t.id = p_to and t.allow_messages = 'nobody')
  and (
    (select allow_messages from profiles where id = p_to) = 'everyone'
    or exists (select 1 from follows f where f.follower_id = p_to and f.following_id = p_from and f.status = 'accepted')
  );
$$;

drop policy if exists "messages_insert" on public.messages;
create policy "messages_insert" on public.messages for insert with check (
  auth.uid() = sender_id
  and exists (select 1 from conversation_members m where m.conversation_id = conversation_id and m.user_id = auth.uid())
  and exists (
    select 1 from conversation_members m2
    where m2.conversation_id = conversation_id and m2.user_id <> auth.uid()
      and can_message(auth.uid(), m2.user_id)
  )
);

-- متابعة مع دعم الحسابات الخاصة
create or replace function public.follow_user(p_target uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_private boolean;
begin
  if v_user is null or v_user = p_target then raise exception 'invalid follow'; end if;
  select is_private into v_private from profiles where id = p_target;
  if exists (select 1 from follows where follower_id = v_user and following_id = p_target) then
    return 'already';
  end if;
  insert into follows (follower_id, following_id, status) values (v_user, p_target, case when v_private then 'pending' else 'accepted' end);
  insert into notifications (user_id, actor_id, kind) values (p_target, v_user, 'follow');
  return case when v_private then 'pending' else 'accepted' end;
end $$;

create or replace function public.unfollow_user(p_target uuid)
returns void language sql security definer set search_path = public as $$
  delete from follows where follower_id = auth.uid() and following_id = p_target;
$$;

-- إدارة (محمية بـ is_admin على الخادم)
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from profiles where id = auth.uid()), false);
$$;

create or replace function public.admin_ban_user(p_target uuid, p_ban boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admin only'; end if;
  update profiles set is_banned = p_ban where id = p_target;
  insert into admin_log (admin_id, action, target) values (auth.uid(), case when p_ban then 'ban' else 'unban' end, p_target::text);
end $$;

create or replace function public.admin_resolve_report(p_report uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admin only'; end if;
  update reports set status = p_status where id = p_report;
  insert into admin_log (admin_id, action, target) values (auth.uid(), 'report_' || p_status, p_report::text);
end $$;

create or replace function public.admin_broadcast(p_title text, p_body text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admin only'; end if;
  insert into notifications (user_id, actor_id, kind, entity_id)
  select id, auth.uid(), 'system', null from profiles where is_banned = false;
  insert into admin_log (admin_id, action, target) values (auth.uid(), 'broadcast', p_title);
end $$;

create or replace function public.admin_set_gift_price(p_gift uuid, p_price integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admin only'; end if;
  if p_price is null or p_price <= 0 then raise exception 'bad price'; end if;
  update gifts set price = p_price where id = p_gift;
  insert into admin_log (admin_id, action, target) values (auth.uid(), 'gift_price', p_gift::text || '=' || p_price);
end $$;

create or replace function public.admin_set_role(p_target uuid, p_admin boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admin only'; end if;
  update profiles set is_admin = p_admin where id = p_target;
  insert into admin_log (admin_id, action, target) values (auth.uid(), 'set_role', p_target::text || '=' || p_admin);
end $$;

create or replace function public.admin_delete_post(p_post uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admin only'; end if;
  delete from posts where id = p_post;
  insert into admin_log (admin_id, action, target) values (auth.uid(), 'delete_post', p_post::text);
end $$;

-- تعديل/حذف تعليق
create or replace function public.update_comment(p_id uuid, p_content text)
returns void language sql security definer set search_path = public as $$
  update comments set content = p_content where id = p_id and user_id = auth.uid();
$$;
create or replace function public.delete_comment(p_id uuid)
returns void language sql security definer set search_path = public as $$
  delete from comments where id = p_id and user_id = auth.uid();
$$;

create policy "mutes_rw" on public.mutes for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "reactions_read" on public.message_reactions for select using (true);
create policy "reactions_write" on public.message_reactions for insert with check (auth.uid() = user_id);
create policy "reactions_delete" on public.message_reactions for delete using (auth.uid() = user_id);
create policy "story_rx_read" on public.story_reactions for select using (true);
create policy "story_rx_write" on public.story_reactions for insert with check (auth.uid() = user_id);
create policy "story_rx_del" on public.story_reactions for delete using (auth.uid() = user_id);
create policy "reel_views_rw" on public.reel_views for insert with check (auth.uid() = viewer_id);
create policy "reel_views_read" on public.reel_views for select using (true);
create policy "live_msg_read" on public.live_messages for select using (true);
create policy "live_msg_write" on public.live_messages for insert with check (auth.uid() = user_id);
create policy "live_msg_del" on public.live_messages for delete using (auth.uid() = user_id);
create policy "admin_log_read" on public.admin_log for select using (is_admin());
create policy "settings_read" on public.app_settings for select using (true);
create policy "settings_admin" on public.app_settings for all using (is_admin()) with check (is_admin());
create policy "follows_update_own" on public.follows for update using (auth.uid() = following_id);

-- منع المستخدمين المحظورين من إكمال التسجيل
create or replace function public.reject_banned()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from profiles where id = new.id and is_banned) then
    raise exception 'account banned';
  end if;
  return new;
end $$;
