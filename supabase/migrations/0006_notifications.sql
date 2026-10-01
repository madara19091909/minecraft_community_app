-- Phase 6: in-app notifications (created by DB triggers, delivered via Realtime).
-- Clients can only read their own notifications and mark them read.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete cascade,
  type text not null check (type in (
    'like', 'comment', 'follow', 'community_request', 'community_approved',
    'community_added', 'role_change', 'system')),
  post_id uuid references public.posts(id) on delete cascade,
  community_id uuid references public.communities(id) on delete cascade,
  message text check (char_length(message) <= 300),   -- used by 'system'
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_recipient_idx on public.notifications (recipient_id, created_at desc);
create index notifications_unread_idx on public.notifications (recipient_id) where read_at is null;
-- Anti-spam: like/unlike/like or follow/unfollow/follow notify only once.
create unique index notif_like_uq on public.notifications (recipient_id, actor_id, post_id)
  where type = 'like';
create unique index notif_follow_uq on public.notifications (recipient_id, actor_id)
  where type = 'follow';
create unique index notif_request_uq on public.notifications (recipient_id, actor_id, community_id)
  where type = 'community_request';

-- ---------- Triggers ----------
create or replace function public.notify_like()
returns trigger language plpgsql security definer set search_path = public as $$
declare author uuid;
begin
  select author_id into author from posts where id = new.post_id;
  if author is not null and author <> new.user_id then
    insert into notifications (recipient_id, actor_id, type, post_id)
    values (author, new.user_id, 'like', new.post_id) on conflict do nothing;
  end if;
  return null;
end $$;
create trigger likes_notify after insert on public.likes
  for each row execute function public.notify_like();

create or replace function public.notify_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare author uuid;
begin
  select author_id into author from posts where id = new.post_id;
  if author is not null and author <> new.author_id then
    insert into notifications (recipient_id, actor_id, type, post_id)
    values (author, new.author_id, 'comment', new.post_id);
  end if;
  return null;
end $$;
create trigger comments_notify after insert on public.comments
  for each row execute function public.notify_comment();

create or replace function public.notify_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into notifications (recipient_id, actor_id, type)
  values (new.following_id, new.follower_id, 'follow') on conflict do nothing;
  return null;
end $$;
create trigger follows_notify after insert on public.follows
  for each row execute function public.notify_follow();

create or replace function public.notify_community_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' then
      insert into notifications (recipient_id, actor_id, type, community_id)
      select m.user_id, new.user_id, 'community_request', new.community_id
      from community_members m
      where m.community_id = new.community_id and m.status = 'active'
        and m.role in ('owner', 'admin', 'moderator')
      on conflict do nothing;
    elsif new.status = 'active' and new.role <> 'owner'
          and auth.uid() is not null and auth.uid() <> new.user_id then
      insert into notifications (recipient_id, actor_id, type, community_id)
      values (new.user_id, auth.uid(), 'community_added', new.community_id);
    end if;
  elsif old.status = 'pending' and new.status = 'active'
        and auth.uid() is not null and auth.uid() <> new.user_id then
    insert into notifications (recipient_id, actor_id, type, community_id)
    values (new.user_id, auth.uid(), 'community_approved', new.community_id);
  end if;
  return null;
end $$;
create trigger community_members_notify after insert or update on public.community_members
  for each row execute function public.notify_community_member();

create or replace function public.notify_role_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role_id is distinct from old.role_id
     and auth.uid() is not null and auth.uid() <> new.id then
    insert into notifications (recipient_id, actor_id, type)
    values (new.id, auth.uid(), 'role_change');
  end if;
  return null;
end $$;
create trigger profiles_role_notify after update of role_id on public.profiles
  for each row execute function public.notify_role_change();

-- ---------- Privileges & RLS ----------
revoke insert, update, delete on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;
grant delete on public.notifications to authenticated;

alter table public.notifications enable row level security;
create policy notifications_select on public.notifications for select to authenticated
  using (recipient_id = auth.uid() and public.is_active_user());
create policy notifications_update on public.notifications for update to authenticated
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
create policy notifications_delete on public.notifications for delete to authenticated
  using (recipient_id = auth.uid());

-- ---------- View + RPC ----------
create or replace view public.notification_details with (security_invoker = true) as
select n.id, n.type, n.post_id, n.community_id, n.message, n.read_at, n.created_at,
       n.actor_id,
       a.username as actor_username,
       a.display_name as actor_display_name,
       a.avatar_url as actor_avatar_url,
       left(p.content, 80) as post_snippet,
       c.name as community_name
from public.notifications n
left join public.profiles a on a.id = n.actor_id
left join public.posts p on p.id = n.post_id
left join public.communities c on c.id = n.community_id
where n.recipient_id = auth.uid();
grant select on public.notification_details to authenticated;

create or replace function public.unread_notification_count()
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from notifications
  where recipient_id = auth.uid() and read_at is null and public.is_active_user();
$$;
revoke execute on function public.unread_notification_count() from public, anon;
grant execute on function public.unread_notification_count() to authenticated;

-- Realtime (subscriber's RLS applies)
alter publication supabase_realtime add table public.notifications;

-- Manual announcement example (run as admin in the SQL editor):
--   insert into notifications (recipient_id, type, message)
--   select id, 'system', 'Server maintenance tonight at 22:00 UTC'
--   from profiles where status = 'active';
