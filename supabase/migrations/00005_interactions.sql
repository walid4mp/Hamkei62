-- Reels + comments + read receipts
create or replace function public.toggle_reel_like(p_reel uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'auth required'; end if;
  if exists (select 1 from reel_likes where reel_id = p_reel and user_id = v_user) then
    delete from reel_likes where reel_id = p_reel and user_id = v_user;
    update reels set like_count = greatest(like_count - 1, 0) where id = p_reel;
  else
    insert into reel_likes (reel_id, user_id) values (p_reel, v_user);
    update reels set like_count = like_count + 1 where id = p_reel;
  end if;
end $$;

create or replace function public.record_reel_view(p_reel uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  insert into reel_views (reel_id, viewer_id) values (p_reel, auth.uid()) on conflict do nothing;
end $$;

create or replace function public.add_comment(p_post uuid, p_content text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_id uuid; v_owner uuid;
begin
  if v_user is null then raise exception 'auth required'; end if;
  if char_length(trim(p_content)) = 0 or char_length(p_content) > 500 then raise exception 'bad comment'; end if;
  insert into comments (post_id, user_id, content) values (p_post, v_user, p_content) returning id into v_id;
  update posts set comment_count = comment_count + 1 where id = p_post;
  select user_id into v_owner from posts where id = p_post;
  if v_owner <> v_user then
    insert into notifications (user_id, actor_id, kind, entity_id) values (v_owner, v_user, 'comment', p_post);
  end if;
  return v_id;
end $$;

create or replace function public.mark_read(p_conv uuid)
returns void language sql security definer set search_path = public as $$
  update messages set read_at = now()
  where conversation_id = p_conv and sender_id <> auth.uid() and read_at is null;
$$;
