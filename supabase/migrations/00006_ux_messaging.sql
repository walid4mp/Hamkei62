-- SocialPlus v1.3 — additive & idempotent (يحافظ على كل البيانات)

-- إعدادات المحادثة لكل مستخدم (تثبيت/كتم/أرشفة)
create table if not exists public.conversation_settings (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  pinned boolean not null default false,
  muted boolean not null default false,
  archived boolean not null default false,
  primary key (conversation_id, user_id)
);
alter table public.conversation_settings enable row level security;
create policy "conv_settings_rw" on public.conversation_settings for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- تسليم الرسائل + تفضيلات الإشعارات
alter table public.messages add column if not exists delivered_at timestamptz;
alter table public.profiles add column if not exists notif_prefs jsonb
  not null default '{"messages":true,"likes":true,"comments":true,"follows":true,"live":true,"gifts":true,"groups":true}'::jsonb;

-- منع تكرار الهدايا (idempotency)
alter table public.gifts_sent add column if not exists idempotency_key text;
create unique index if not exists gifts_idem_idx on public.gifts_sent (idempotency_key) where idempotency_key is not null;

create or replace function public.send_gift(p_gift_id uuid, p_receiver uuid, p_stream_id uuid default null, p_qty integer default 1, p_idem text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_price integer; v_total integer;
begin
  if v_user is null then raise exception 'auth required'; end if;
  if p_idem is not null and exists (select 1 from gifts_sent where idempotency_key = p_idem) then return; end if;
  select price into v_price from gifts where id = p_gift_id;
  if v_price is null then raise exception 'gift not found'; end if;
  v_total := v_price * greatest(p_qty, 1);
  update profiles set coins = coins - v_total where id = v_user and coins >= v_total;
  if not found then raise exception 'insufficient coins'; end if;
  update profiles set coins = coins + v_total where id = p_receiver;
  insert into gifts_sent (gift_id, sender_id, receiver_id, stream_id, quantity, idempotency_key)
    values (p_gift_id, v_user, p_receiver, p_stream_id, greatest(p_qty,1), p_idem);
  insert into coin_transactions (user_id, amount, reason, meta) values
    (v_user, -v_total, 'gift_sent', jsonb_build_object('gift', p_gift_id)),
    (p_receiver, v_total, 'gift_received', jsonb_build_object('gift', p_gift_id));
  insert into notifications (user_id, actor_id, kind, entity_id) values (p_receiver, v_user, 'system', p_gift_id);
end $$;

-- توثيق الحسابات من الإدارة
create or replace function public.admin_verify_user(p_target uuid, p_verified boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admin only'; end if;
  update profiles set is_verified = p_verified where id = p_target;
  insert into admin_log (admin_id, action, target) values (auth.uid(), 'verify', p_target::text || '=' || p_verified);
end $$;

-- تعديل منشور (صاحبه فقط)
create or replace function public.update_post(p_post uuid, p_content text)
returns void language sql security definer set search_path = public as $$
  update posts set content = p_content where id = p_post and user_id = auth.uid();
$$;
