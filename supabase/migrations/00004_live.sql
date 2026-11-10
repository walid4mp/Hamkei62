create or replace function public.stream_join(p_stream uuid)
returns void language sql security definer set search_path = public as $$
  update streams set viewer_count = viewer_count + 1,
    peak_viewers = greatest(peak_viewers, viewer_count + 1)
  where id = p_stream and status = 'live';
$$;

create or replace function public.stream_leave(p_stream uuid)
returns void language sql security definer set search_path = public as $$
  update streams set viewer_count = greatest(viewer_count - 1, 0) where id = p_stream;
$$;

create or replace function public.stream_end(p_stream uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from streams where id = p_stream and host_id = auth.uid())
     and not is_admin() then raise exception 'host only'; end if;
  update streams set status = 'ended', ended_at = now(), viewer_count = 0 where id = p_stream;
end $$;

create or replace function public.stream_comment(p_stream uuid, p_content text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'auth required'; end if;
  if char_length(p_content) = 0 or char_length(p_content) > 300 then raise exception 'bad message'; end if;
  insert into live_messages (stream_id, user_id, content) values (p_stream, auth.uid(), p_content);
end $$;
