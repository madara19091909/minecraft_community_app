-- Phase 7: user blocks, per-user settings (privacy + notification prefs), reports.
-- Everything is enforced server-side; the app only reflects it.

-- =====================================================================
-- Blocks
-- =====================================================================
create table public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index user_blocks_blocked_idx on public.user_blocks (blocked_id);
alter table public.user_blocks enable row level security;
revoke insert, update on public.user_blocks from authenticated;   -- inserts go through block_user()
create policy user_blocks_select on public.user_blocks for select to authenticated
  using (blocker_id = auth.uid());
create policy user_blocks_delete on public.user_blocks for delete to authenticated
  using (blocker_id = auth.uid());

create or replace function public.is_blocked_between(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from user_blocks
                 where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a));
$$;

create or replace function public.block_user(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or not public.is_active_user() then raise exception 'Not allowed'; end if;
  if p_user = me then raise exception 'You cannot block yourself'; end if;
  insert into user_blocks (blocker_id, blocked_id) values (me, p_user) on conflict do nothing;
  delete from follows
  where (follower_id = me and following_id = p_user) or (follower_id = p_user and following_id = me);
end $$;
revoke execute on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;

-- =====================================================================
-- Settings
-- =====================================================================
create table public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  who_can_message text not null default 'everyone'
    check (who_can_message in ('everyone', 'following', 'nobody')),
  profile_visibility text not null default 'everyone'
    check (profile_visibility in ('everyone', 'followers')),
  who_can_mention text not null default 'everyone'
    check (who_can_mention in ('everyone', 'following', 'nobody')),
  notify_messages boolean not null default true,
  notify_likes boolean not null default true,
  notify_comments boolean not null default true,
  notify_follows boolean not null default true,
  notify_communities boolean not null default true,
  notify_system boolean not null default true,
  updated_at timestamptz not null default now()
);
create trigger user_settings_updated_at before update on public.user_settings
  for each row execute function public.set_updated_at();
alter table public.user_settings enable row level security;
create policy user_settings_select on public.user_settings for select to authenticated
  using (user_id = auth.uid());
create policy user_settings_insert on public.user_settings for insert to authenticated
  with check (user_id = auth.uid() and public.is_active_user());
create policy user_settings_update on public.user_settings for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.wants_notification(p_user uuid, p_kind text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select case p_kind
      when 'likes' then notify_likes when 'comments' then notify_comments
      when 'follows' then notify_follows when 'communities' then notify_communities
      when 'system' then notify_system when 'messages' then notify_messages
      else true end
    from user_settings where user_id = p_user), true);
$$;

create or replace function public.can_message_user(p_target uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select not public.is_blocked_between(auth.uid(), p_target)
    and case coalesce((select who_can_message from user_settings where user_id = p_target), 'everyone')
      when 'everyone' then true
      when 'nobody' then false
      else exists (select 1 from follows where follower_id = p_target and following_id = auth.uid())
    end;
$$;

create or replace function public.dm_allowed(p_conversation uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from conversations c
    join conversation_members m on m.conversation_id = c.id and m.user_id <> auth.uid()
    where c.id = p_conversation and not c.is_group and not public.can_message_user(m.user_id));
$$;

create or replace function public.profile_is_visible(p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_profile = auth.uid()
    or coalesce((select profile_visibility from user_settings where user_id = p_profile), 'everyone') = 'everyone'
    or exists (select 1 from follows where follower_id = auth.uid() and following_id = p_profile)
    or public.has_permission('users.manage');
$$;

-- Enforce blocks + messaging preference on the write paths.
drop policy follows_insert on public.follows;
create policy follows_insert on public.follows for insert to authenticated
  with check (follower_id = auth.uid() and public.is_active_user()
              and not public.is_blocked_between(follower_id, following_id));

drop policy messages_insert on public.messages;
create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = auth.uid()
              and public.is_conversation_member(conversation_id)
              and public.has_permission('messages.send')
              and public.dm_allowed(conversation_id));

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
  if not public.can_message_user(p_other) then
    raise exception 'This user is not accepting messages from you';
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

-- Notification triggers now honour preferences and blocks.
create or replace function public.notify_like()
returns trigger language plpgsql security definer set search_path = public as $$
declare author uuid;
begin
  select author_id into author from posts where id = new.post_id;
  if author is not null and author <> new.user_id
     and public.wants_notification(author, 'likes')
     and not public.is_blocked_between(author, new.user_id) then
    insert into notifications (recipient_id, actor_id, type, post_id)
    values (author, new.user_id, 'like', new.post_id) on conflict do nothing;
  end if;
  return null;
end $$;

create or replace function public.notify_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare author uuid;
begin
  select author_id into author from posts where id = new.post_id;
  if author is not null and author <> new.author_id
     and public.wants_notification(author, 'comments')
     and not public.is_blocked_between(author, new.author_id) then
    insert into notifications (recipient_id, actor_id, type, post_id)
    values (author, new.author_id, 'comment', new.post_id);
  end if;
  return null;
end $$;

create or replace function public.notify_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.wants_notification(new.following_id, 'follows') then
    insert into notifications (recipient_id, actor_id, type)
    values (new.following_id, new.follower_id, 'follow') on conflict do nothing;
  end if;
  return null;
end $$;

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
        and public.wants_notification(m.user_id, 'communities')
      on conflict do nothing;
    elsif new.status = 'active' and new.role <> 'owner'
          and auth.uid() is not null and auth.uid() <> new.user_id
          and public.wants_notification(new.user_id, 'communities') then
      insert into notifications (recipient_id, actor_id, type, community_id)
      values (new.user_id, auth.uid(), 'community_added', new.community_id);
    end if;
  elsif old.status = 'pending' and new.status = 'active'
        and auth.uid() is not null and auth.uid() <> new.user_id
        and public.wants_notification(new.user_id, 'communities') then
    insert into notifications (recipient_id, actor_id, type, community_id)
    values (new.user_id, auth.uid(), 'community_approved', new.community_id);
  end if;
  return null;
end $$;

create or replace function public.notify_role_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role_id is distinct from old.role_id
     and auth.uid() is not null and auth.uid() <> new.id
     and public.wants_notification(new.id, 'system') then
    insert into notifications (recipient_id, actor_id, type)
    values (new.id, auth.uid(), 'role_change');
  end if;
  return null;
end $$;

-- =====================================================================
-- Views honouring blocks / profile visibility
-- =====================================================================
create or replace view public.feed_posts with (security_invoker = true) as
select
  p.id, p.author_id, p.content, p.likes_count, p.comments_count, p.created_at,
  pr.username, pr.display_name, pr.avatar_url,
  r.key as author_role_key,
  coalesce((select json_agg(json_build_object('url', m.url, 'kind', m.kind) order by m.position)
            from public.post_media m where m.post_id = p.id), '[]'::json) as media,
  exists (select 1 from public.likes l
          where l.post_id = p.id and l.user_id = auth.uid()) as liked_by_me,
  p.community_id,
  c.name as community_name
from public.posts p
join public.profiles pr on pr.id = p.author_id and pr.status = 'active'
join public.roles r on r.id = pr.role_id
left join public.communities c on c.id = p.community_id
where not public.is_blocked_between(auth.uid(), p.author_id);

create or replace view public.comment_details with (security_invoker = true) as
select c.id, c.post_id, c.author_id, c.content, c.created_at,
       pr.username, pr.display_name, pr.avatar_url
from public.comments c
join public.profiles pr on pr.id = c.author_id and pr.status = 'active'
where not public.is_blocked_between(auth.uid(), c.author_id);

create or replace view public.profile_details with (security_invoker = true) as
select
  p.id, p.username, p.display_name, p.avatar_url,
  case when public.profile_is_visible(p.id) then p.banner_url end as banner_url,
  case when public.profile_is_visible(p.id) then p.bio end as bio,
  case when public.profile_is_visible(p.id) then p.minecraft_username end as minecraft_username,
  case when public.profile_is_visible(p.id) then p.minecraft_edition end as minecraft_edition,
  case when public.profile_is_visible(p.id) then p.links else '{}'::jsonb end as links,
  p.status, p.created_at,
  r.key as role_key,
  r.name as role_name,
  (select count(*) from public.follows f where f.following_id = p.id) as followers_count,
  (select count(*) from public.follows f where f.follower_id = p.id) as following_count,
  exists (select 1 from public.follows f
          where f.follower_id = auth.uid() and f.following_id = p.id) as is_following,
  not public.profile_is_visible(p.id) as is_restricted
from public.profiles p
join public.roles r on r.id = p.role_id
where (p.status = 'active' or p.id = auth.uid())
  and (p.id = auth.uid() or not public.is_blocked_between(auth.uid(), p.id));

create or replace view public.user_directory with (security_invoker = true) as
select p.id, p.username, p.display_name, p.avatar_url
from public.profiles p
where p.status = 'active' and not public.is_blocked_between(auth.uid(), p.id);

create or replace view public.blocked_user_details with (security_invoker = true) as
select b.blocked_id as user_id, b.created_at, p.username, p.display_name, p.avatar_url
from public.user_blocks b
join public.profiles p on p.id = b.blocked_id
where b.blocker_id = auth.uid();

grant select on public.profile_details, public.user_directory,
  public.blocked_user_details to authenticated;

-- =====================================================================
-- Reports
-- =====================================================================
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('user', 'post', 'comment', 'message', 'community')),
  target_id uuid not null,
  target_owner_id uuid references public.profiles(id) on delete set null,
  target_snapshot text,                      -- kept so moderators can judge even if content is deleted
  reason text not null check (reason in
    ('spam', 'harassment', 'hate', 'sexual', 'violence', 'impersonation', 'other')),
  description text check (char_length(description) <= 500),
  status text not null default 'pending'
    check (status in ('pending', 'reviewing', 'resolved', 'rejected')),
  resolution_note text check (char_length(resolution_note) <= 500),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index reports_open_uq on public.reports (reporter_id, target_type, target_id)
  where status in ('pending', 'reviewing');
create index reports_status_idx on public.reports (status, created_at desc);
create index reports_target_idx on public.reports (target_type, target_id);
create trigger reports_updated_at before update on public.reports
  for each row execute function public.set_updated_at();

alter table public.reports enable row level security;
revoke insert, update, delete on public.reports from authenticated;
create policy reports_select on public.reports for select to authenticated
  using (reporter_id = auth.uid() or public.has_permission('reports.review'));

create or replace function public.submit_report(
  p_type text, p_target uuid, p_reason text, p_description text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); owner uuid; snap text; cid uuid; rid uuid;
begin
  if me is null or not public.is_active_user() then raise exception 'Not allowed'; end if;
  if (select count(*) from reports where reporter_id = me
        and created_at > now() - interval '1 day') >= 20 then
    raise exception 'Daily report limit reached. Try again tomorrow.';
  end if;

  if p_type = 'user' then
    select id, '@' || username into owner, snap from profiles where id = p_target and status = 'active';
  elsif p_type = 'post' then
    select p.author_id, left(p.content, 200), p.community_id into owner, snap, cid
    from posts p where p.id = p_target;
    if cid is not null and not public.can_view_community(cid) then owner := null; end if;
  elsif p_type = 'comment' then
    select c.author_id, left(c.content, 200), p.community_id into owner, snap, cid
    from comments c join posts p on p.id = c.post_id where c.id = p_target;
    if cid is not null and not public.can_view_community(cid) then owner := null; end if;
  elsif p_type = 'message' then
    select m.sender_id, left(m.content, 200) into owner, snap
    from messages m
    where m.id = p_target and m.deleted_at is null and public.is_conversation_member(m.conversation_id);
  elsif p_type = 'community' then
    select c.owner_id, c.name into owner, snap from communities c where c.id = p_target;
  else
    raise exception 'Invalid report type';
  end if;

  if owner is null then raise exception 'Nothing to report'; end if;
  if owner = me then raise exception 'You cannot report yourself or your own content'; end if;

  begin
    insert into reports (reporter_id, target_type, target_id, target_owner_id, target_snapshot,
                         reason, description)
    values (me, p_type, p_target, owner, snap, p_reason, nullif(btrim(coalesce(p_description, '')), ''))
    returning id into rid;
  exception when unique_violation then
    raise exception 'You have already reported this';
  end;
  return rid;
end $$;

create or replace function public.review_report(p_id uuid, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_permission('reports.review') then raise exception 'Not allowed'; end if;
  if p_status not in ('reviewing', 'resolved', 'rejected') then raise exception 'Invalid status'; end if;
  update reports
     set status = p_status,
         resolution_note = nullif(btrim(coalesce(p_note, '')), ''),
         reviewed_by = auth.uid(),
         reviewed_at = now()
   where id = p_id;
  if not found then raise exception 'Report not found'; end if;
end $$;

revoke execute on function public.submit_report(text, uuid, text, text),
  public.review_report(uuid, text, text) from public, anon;
grant execute on function public.submit_report(text, uuid, text, text),
  public.review_report(uuid, text, text) to authenticated;

create or replace view public.report_details with (security_invoker = true) as
select r.id, r.reporter_id, r.target_type, r.target_id, r.target_owner_id, r.target_snapshot,
       r.reason, r.description, r.status, r.resolution_note, r.reviewed_at, r.created_at,
       rp.username as reporter_username,
       ow.username as owner_username,
       rv.username as reviewer_username
from public.reports r
left join public.profiles rp on rp.id = r.reporter_id
left join public.profiles ow on ow.id = r.target_owner_id
left join public.profiles rv on rv.id = r.reviewed_by;
grant select on public.report_details to authenticated;
