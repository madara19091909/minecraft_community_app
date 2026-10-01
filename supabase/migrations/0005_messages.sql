-- Phase 5: direct & group messaging (Realtime-ready).
-- Conversations/members are created ONLY through SECURITY DEFINER RPCs so a
-- client can never add itself to someone else's conversation.

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  is_group boolean not null default false,
  title text check (title is null or char_length(btrim(title)) between 1 and 60),
  created_by uuid not null references public.profiles(id),
  direct_key text unique,                  -- "<lowUuid>:<highUuid>" for 1:1 chats
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((is_group and direct_key is null) or (not is_group and direct_key is not null))
);
create index conversations_last_msg_idx on public.conversations (last_message_at desc);
create trigger conversations_updated_at before update on public.conversations
  for each row execute function public.set_updated_at();

create table public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create index conversation_members_user_idx on public.conversation_members (user_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  content text not null default '' check (char_length(content) <= 4000),
  media_path text,
  reply_to uuid references public.messages(id) on delete set null,
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  check (deleted_at is not null or char_length(btrim(content)) > 0 or media_path is not null)
);
create index messages_conv_created_idx on public.messages (conversation_id, created_at desc);

-- ---------- Helpers ----------
create or replace function public.is_conversation_member(p_conversation uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_active_user() and exists (
    select 1 from conversation_members
    where conversation_id = p_conversation and user_id = auth.uid());
$$;

-- Storage path layout: <conversation_id>/<sender_id>/<file>
create or replace function public.can_access_chat_object(p_name text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare cid uuid;
begin
  begin
    cid := (storage.foldername(p_name))[1]::uuid;
  exception when others then
    return false;
  end;
  return public.is_conversation_member(cid);
end $$;

-- ---------- Message triggers ----------
create or replace function public.messages_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.reply_to is not null and not exists (
    select 1 from messages m where m.id = new.reply_to and m.conversation_id = new.conversation_id
  ) then
    raise exception 'Invalid reply target';
  end if;
  return new;
end $$;
create trigger messages_before_insert_trg before insert on public.messages
  for each row execute function public.messages_before_insert();

create or replace function public.messages_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update conversations set last_message_at = new.created_at where id = new.conversation_id;
  return null;
end $$;
create trigger messages_after_insert_trg after insert on public.messages
  for each row execute function public.messages_after_insert();

create or replace function public.messages_before_update()
returns trigger language plpgsql as $$
begin
  if old.deleted_at is not null then
    raise exception 'This message was deleted';
  end if;
  if new.deleted_at is not null then
    new.deleted_at := now();
    new.content := '';
    new.media_path := null;
  elsif new.content is distinct from old.content then
    if old.media_path is null and char_length(btrim(new.content)) = 0 then
      raise exception 'Message cannot be empty';
    end if;
    new.edited_at := now();
  end if;
  return new;
end $$;
create trigger messages_before_update_trg before update on public.messages
  for each row execute function public.messages_before_update();

-- ---------- Privileges ----------
revoke insert, update, delete on public.conversations from authenticated;
revoke insert, update on public.conversation_members from authenticated;
revoke insert, update, delete on public.messages from authenticated;
grant insert (conversation_id, sender_id, content, media_path, reply_to)
  on public.messages to authenticated;
grant update (content, deleted_at) on public.messages to authenticated;

-- ---------- RLS ----------
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

create policy conversations_select on public.conversations for select to authenticated
  using (public.is_conversation_member(id));

create policy cmembers_select on public.conversation_members for select to authenticated
  using (public.is_conversation_member(conversation_id));
create policy cmembers_leave_group on public.conversation_members for delete to authenticated
  using (user_id = auth.uid()
         and exists (select 1 from public.conversations c
                     where c.id = conversation_id and c.is_group));

create policy messages_select on public.messages for select to authenticated
  using (public.is_conversation_member(conversation_id));
create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = auth.uid()
              and public.is_conversation_member(conversation_id)
              and public.has_permission('messages.send'));
create policy messages_update_own on public.messages for update to authenticated
  using (sender_id = auth.uid() and public.is_conversation_member(conversation_id))
  with check (sender_id = auth.uid());

-- ---------- RPCs ----------
create or replace function public.start_direct_conversation(p_other uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); k text; cid uuid;
begin
  if me is null or not public.has_permission('messages.send') then
    raise exception 'You are not allowed to send messages';
  end if;
  if p_other = me then raise exception 'You cannot message yourself'; end if;
  if not exists (select 1 from profiles where id = p_other and status = 'active') then
    raise exception 'User not found';
  end if;
  k := least(me::text, p_other::text) || ':' || greatest(me::text, p_other::text);
  select id into cid from conversations where direct_key = k;
  if cid is null then
    insert into conversations (is_group, created_by, direct_key)
    values (false, me, k) on conflict (direct_key) do nothing returning id into cid;
    if cid is null then select id into cid from conversations where direct_key = k; end if;
    insert into conversation_members (conversation_id, user_id)
    values (cid, me), (cid, p_other) on conflict do nothing;
  end if;
  return cid;
end $$;

create or replace function public.create_group_conversation(p_title text, p_members uuid[])
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); cid uuid; ids uuid[];
begin
  if me is null or not public.has_permission('messages.send') then
    raise exception 'You are not allowed to send messages';
  end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 60 then
    raise exception 'Group name must be 1-60 characters';
  end if;
  select coalesce(array_agg(distinct u), '{}') into ids
  from unnest(p_members) u where u <> me;
  if coalesce(array_length(ids, 1), 0) not between 1 and 49 then
    raise exception 'Choose between 1 and 49 members';
  end if;
  if (select count(*) from profiles where id = any(ids) and status = 'active')
     <> array_length(ids, 1) then
    raise exception 'One or more users were not found';
  end if;
  insert into conversations (is_group, title, created_by)
  values (true, btrim(p_title), me) returning id into cid;
  insert into conversation_members (conversation_id, user_id, role) values (cid, me, 'admin');
  insert into conversation_members (conversation_id, user_id)
  select cid, unnest(ids);
  return cid;
end $$;

create or replace function public.mark_conversation_read(p_conversation uuid)
returns void language sql security definer set search_path = public as $$
  update conversation_members set last_read_at = now()
  where conversation_id = p_conversation and user_id = auth.uid();
$$;

revoke execute on function public.start_direct_conversation(uuid),
  public.create_group_conversation(text, uuid[]),
  public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.start_direct_conversation(uuid),
  public.create_group_conversation(text, uuid[]),
  public.mark_conversation_read(uuid) to authenticated;

-- ---------- Views ----------
create or replace view public.conversation_summaries with (security_invoker = true) as
select
  c.id, c.is_group, c.title, c.last_message_at, me.last_read_at,
  (select count(*) from public.messages m
    where m.conversation_id = c.id and m.sender_id <> auth.uid()
      and m.deleted_at is null and m.created_at > me.last_read_at) as unread_count,
  lm.content as last_content,
  lm.sender_id as last_sender_id,
  (lm.media_path is not null) as last_has_media,
  (lm.deleted_at is not null) as last_deleted,
  other.user_id as other_user_id,
  op.username as other_username,
  op.display_name as other_display_name,
  op.avatar_url as other_avatar_url,
  (select count(*) from public.conversation_members x where x.conversation_id = c.id) as member_count
from public.conversations c
join public.conversation_members me
  on me.conversation_id = c.id and me.user_id = auth.uid()
left join lateral (
  select m.content, m.sender_id, m.media_path, m.deleted_at
  from public.messages m where m.conversation_id = c.id
  order by m.created_at desc limit 1
) lm on true
left join lateral (
  select x.user_id from public.conversation_members x
  where x.conversation_id = c.id and x.user_id <> auth.uid() limit 1
) other on not c.is_group
left join public.profiles op on op.id = other.user_id;

create or replace view public.conversation_member_details with (security_invoker = true) as
select cm.conversation_id, cm.user_id, cm.role, cm.joined_at, cm.last_read_at,
       p.username, p.display_name, p.avatar_url
from public.conversation_members cm
join public.profiles p on p.id = cm.user_id;

grant select on public.conversation_summaries, public.conversation_member_details to authenticated;

-- ---------- Storage (private bucket: images are served via signed URLs) ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-media', 'chat-media', false, 8388608, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "chat_media_select" on storage.objects for select to authenticated
  using (bucket_id = 'chat-media' and public.can_access_chat_object(name));
create policy "chat_media_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-media'
              and public.can_access_chat_object(name)
              and (storage.foldername(name))[2] = auth.uid()::text);
create policy "chat_media_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'chat-media' and (storage.foldername(name))[2] = auth.uid()::text);

-- ---------- Realtime ----------
-- Realtime applies the subscriber's RLS, so users only receive their own chats.
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.conversation_members;
