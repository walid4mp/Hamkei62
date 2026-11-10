-- SocialPlus messaging repair: conversation RLS + safe conversation creation.
-- Apply after 00006_ux_messaging.sql in Supabase SQL Editor.
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

drop policy if exists conversations_member_read on public.conversations;
create policy conversations_member_read on public.conversations
for select using (
  exists (select 1 from public.conversation_members cm
          where cm.conversation_id = conversations.id and cm.user_id = auth.uid())
);

drop policy if exists conversations_member_update on public.conversations;
create policy conversations_member_update on public.conversations
for update using (
  exists (select 1 from public.conversation_members cm
          where cm.conversation_id = conversations.id and cm.user_id = auth.uid())
);

drop policy if exists members_read_participants on public.conversation_members;
create policy members_read_participants on public.conversation_members
for select using (
  exists (select 1 from public.conversation_members cm
          where cm.conversation_id = conversation_members.conversation_id
            and cm.user_id = auth.uid())
);

drop policy if exists members_insert_self_or_group_admin on public.conversation_members;
create policy members_insert_self_or_group_admin on public.conversation_members
for insert with check (
  user_id = auth.uid()
  or exists (
    select 1 from public.conversation_members cm
    join public.conversations c on c.id = cm.conversation_id
    where cm.conversation_id = conversation_members.conversation_id
      and cm.user_id = auth.uid() and c.is_group = true
  )
);

drop policy if exists members_delete_self on public.conversation_members;
create policy members_delete_self on public.conversation_members
for delete using (user_id = auth.uid());

drop policy if exists messages_member_read on public.messages;
create policy messages_member_read on public.messages
for select using (
  exists (select 1 from public.conversation_members cm
          where cm.conversation_id = messages.conversation_id and cm.user_id = auth.uid())
);

drop policy if exists messages_member_insert on public.messages;
create policy messages_member_insert on public.messages
for insert with check (
  sender_id = auth.uid()
  and exists (select 1 from public.conversation_members cm
              where cm.conversation_id = messages.conversation_id and cm.user_id = auth.uid())
  and exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = messages.conversation_id and cm.user_id <> auth.uid()
      and public.can_message(auth.uid(), cm.user_id)
  )
);

create or replace function public.create_direct_conversation(p_other_user uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_conv uuid;
begin
  if v_me is null then raise exception 'auth_required'; end if;
  if p_other_user is null or p_other_user = v_me then raise exception 'invalid_user'; end if;
  if not exists (select 1 from public.profiles where id = p_other_user and coalesce(is_banned,false) = false) then
    raise exception 'user_not_found';
  end if;
  if not public.can_message(v_me, p_other_user) then raise exception 'messaging_not_allowed'; end if;

  select c.id into v_conv
  from public.conversations c
  where c.is_group = false
    and exists (select 1 from public.conversation_members a where a.conversation_id=c.id and a.user_id=v_me)
    and exists (select 1 from public.conversation_members b where b.conversation_id=c.id and b.user_id=p_other_user)
    and (select count(*) from public.conversation_members x where x.conversation_id=c.id)=2
  limit 1;

  if v_conv is null then
    insert into public.conversations(is_group, title) values(false, null) returning id into v_conv;
    insert into public.conversation_members(conversation_id,user_id)
      values(v_conv,v_me),(v_conv,p_other_user);
  end if;
  return v_conv;
end $$;

create or replace function public.create_group_conversation(p_title text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_conv uuid;
begin
  if v_me is null then raise exception 'auth_required'; end if;
  if length(trim(coalesce(p_title,''))) < 2 then raise exception 'group_name_required'; end if;
  insert into public.conversations(is_group,title) values(true,trim(p_title)) returning id into v_conv;
  insert into public.conversation_members(conversation_id,user_id) values(v_conv,v_me);
  return v_conv;
end $$;

grant execute on function public.create_direct_conversation(uuid) to authenticated;
grant execute on function public.create_group_conversation(text) to authenticated;

create index if not exists conversation_members_user_idx
  on public.conversation_members(user_id, conversation_id);
create index if not exists conversations_updated_idx
  on public.conversations(updated_at desc);
