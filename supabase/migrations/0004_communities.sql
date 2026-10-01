-- Phase 4: communities, membership, community posts.
-- Private communities are discoverable (name/description) but their posts and
-- member lists are visible only to active members. Joining: public = instant,
-- private = request + approval, or direct add by community admin/owner.

-- ---------- Permission ----------
insert into public.permissions (key, description)
values ('communities.create', 'Create communities')
on conflict (key) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r, public.permissions p
where p.key = 'communities.create'
  and r.key in ('creator', 'staff', 'developer', 'moderator', 'admin', 'owner')
on conflict do nothing;

-- ---------- Tables ----------
create table public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 3 and 40),
  description text check (char_length(description) <= 300),
  rules text check (char_length(rules) <= 1000),
  icon_url text,
  banner_url text,
  owner_id uuid not null references public.profiles(id),
  privacy text not null default 'public' check (privacy in ('public', 'private')),
  member_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index communities_name_key on public.communities (lower(btrim(name)));
create index communities_created_idx on public.communities (created_at desc);
create trigger communities_updated_at before update on public.communities
  for each row execute function public.set_updated_at();

create table public.community_members (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'moderator', 'member')),
  status text not null default 'active' check (status in ('active', 'pending')),
  joined_at timestamptz not null default now(),
  primary key (community_id, user_id)
);
create index community_members_user_idx on public.community_members (user_id);
create index community_members_list_idx
  on public.community_members (community_id, status, joined_at);

alter table public.posts
  add column community_id uuid references public.communities(id) on delete cascade;
create index posts_community_idx on public.posts (community_id, created_at desc)
  where community_id is not null;

-- ---------- Helper functions (SECURITY DEFINER: no RLS recursion) ----------
create or replace function public.community_role_of(p_community uuid)
returns text language sql stable security definer set search_path = public as $$
  select m.role from community_members m
  where m.community_id = p_community and m.user_id = auth.uid()
    and m.status = 'active' and public.is_active_user();
$$;

create or replace function public.is_community_member(p_community uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.community_role_of(p_community) is not null;
$$;

create or replace function public.can_moderate_community(p_community uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.community_role_of(p_community) in ('owner', 'admin', 'moderator'), false)
         or public.has_permission('communities.manage');
$$;

create or replace function public.can_manage_community(p_community uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.community_role_of(p_community) in ('owner', 'admin'), false)
         or public.has_permission('communities.manage');
$$;

create or replace function public.can_view_community(p_community uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from communities c where c.id = p_community and c.privacy = 'public')
         or public.is_community_member(p_community)
         or public.has_permission('communities.manage');
$$;

-- ---------- Triggers ----------
create or replace function public.add_owner_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into community_members (community_id, user_id, role, status)
  values (new.id, new.owner_id, 'owner', 'active');
  return null;
end $$;
create trigger communities_add_owner after insert on public.communities
  for each row execute function public.add_owner_member();

create or replace function public.bump_member_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' and new.status = 'active' then
    update communities set member_count = member_count + 1 where id = new.community_id;
  elsif tg_op = 'DELETE' and old.status = 'active' then
    update communities set member_count = greatest(member_count - 1, 0) where id = old.community_id;
  elsif tg_op = 'UPDATE' and old.status <> new.status then
    if new.status = 'active' then
      update communities set member_count = member_count + 1 where id = new.community_id;
    elsif old.status = 'active' then
      update communities set member_count = greatest(member_count - 1, 0) where id = new.community_id;
    end if;
  end if;
  return null;
end $$;
create trigger community_members_count after insert or update or delete
  on public.community_members for each row execute function public.bump_member_count();

-- Role changes: owner is immutable; only owner may create/modify admins.
create or replace function public.guard_member_update()
returns trigger language plpgsql security definer set search_path = public as $$
declare actor_role text;
begin
  if auth.uid() is null then return new; end if;
  if new.user_id <> old.user_id or new.community_id <> old.community_id then
    raise exception 'immutable columns';
  end if;
  if old.role = 'owner' and (new.role <> old.role or new.status <> old.status) then
    raise exception 'the owner cannot be modified';
  end if;
  if new.role <> old.role then
    if new.role = 'owner' then raise exception 'ownership cannot be assigned'; end if;
    if not public.can_manage_community(old.community_id) then
      raise exception 'only owner/admin can change roles';
    end if;
    actor_role := public.community_role_of(old.community_id);
    if (new.role = 'admin' or old.role = 'admin')
       and coalesce(actor_role, '') <> 'owner'
       and not public.has_permission('communities.manage') then
      raise exception 'only the owner can manage admins';
    end if;
  end if;
  return new;
end $$;
create trigger community_members_guard before update on public.community_members
  for each row execute function public.guard_member_update();

-- ---------- Privileges ----------
revoke insert, update on public.communities from authenticated;
grant insert (name, description, rules, icon_url, banner_url, owner_id, privacy)
  on public.communities to authenticated;
grant update (name, description, rules, icon_url, banner_url, privacy)
  on public.communities to authenticated;
revoke update on public.community_members from authenticated;
grant update (role, status) on public.community_members to authenticated;
grant insert (community_id) on public.posts to authenticated;

-- ---------- RLS: communities ----------
alter table public.communities enable row level security;
alter table public.community_members enable row level security;

create policy communities_select on public.communities for select to authenticated
  using (public.is_active_user());
create policy communities_insert on public.communities for insert to authenticated
  with check (owner_id = auth.uid() and public.has_permission('communities.create'));
create policy communities_update on public.communities for update to authenticated
  using (public.can_manage_community(id)) with check (public.can_manage_community(id));
create policy communities_delete on public.communities for delete to authenticated
  using ((owner_id = auth.uid() and public.is_active_user())
         or public.has_permission('communities.manage'));

-- ---------- RLS: members ----------
create policy cm_select on public.community_members for select to authenticated
  using (user_id = auth.uid()
         or (status = 'active' and public.is_active_user() and public.can_view_community(community_id))
         or public.can_moderate_community(community_id));

create policy cm_insert on public.community_members for insert to authenticated
  with check (
    (user_id = auth.uid() and role = 'member'
     and public.has_permission('communities.join')
     and exists (select 1 from public.communities c
                 where c.id = community_id
                   and ((c.privacy = 'public' and status = 'active')
                     or (c.privacy = 'private' and status = 'pending'))))
    or (public.can_manage_community(community_id) and role <> 'owner' and status = 'active')
  );

create policy cm_update on public.community_members for update to authenticated
  using (public.can_moderate_community(community_id))
  with check (public.can_moderate_community(community_id));

create policy cm_delete on public.community_members for delete to authenticated
  using (
    (user_id = auth.uid() and role <> 'owner')
    or (role = 'member' and public.can_moderate_community(community_id))
    or (role in ('member', 'moderator') and public.can_manage_community(community_id))
    or (role <> 'owner' and public.has_permission('communities.manage'))
  );

-- ---------- RLS: posts & dependants respect community visibility ----------
drop policy posts_select on public.posts;
create policy posts_select on public.posts for select to authenticated
  using (public.is_active_user()
         and (community_id is null or public.can_view_community(community_id)));

drop policy posts_insert on public.posts;
create policy posts_insert on public.posts for insert to authenticated
  with check (author_id = auth.uid() and public.has_permission('posts.create')
              and (community_id is null or public.is_community_member(community_id)));

drop policy posts_delete on public.posts;
create policy posts_delete on public.posts for delete to authenticated
  using ((author_id = auth.uid() and public.is_active_user())
         or public.has_permission('content.moderate')
         or (community_id is not null and public.can_moderate_community(community_id)));

-- Subqueries on posts run under the caller's RLS, so these inherit post visibility.
drop policy post_media_select on public.post_media;
create policy post_media_select on public.post_media for select to authenticated
  using (public.is_active_user() and exists (select 1 from public.posts p where p.id = post_id));

drop policy likes_select on public.likes;
create policy likes_select on public.likes for select to authenticated
  using (public.is_active_user() and exists (select 1 from public.posts p where p.id = post_id));

drop policy likes_insert on public.likes;
create policy likes_insert on public.likes for insert to authenticated
  with check (user_id = auth.uid() and public.is_active_user()
              and exists (select 1 from public.posts p where p.id = post_id));

drop policy comments_select on public.comments;
create policy comments_select on public.comments for select to authenticated
  using (public.is_active_user() and exists (select 1 from public.posts p where p.id = post_id));

drop policy comments_insert on public.comments;
create policy comments_insert on public.comments for insert to authenticated
  with check (author_id = auth.uid() and public.has_permission('comments.create')
              and exists (select 1 from public.posts p where p.id = post_id));

drop policy comments_delete on public.comments;
create policy comments_delete on public.comments for delete to authenticated
  using ((author_id = auth.uid() and public.is_active_user())
         or public.has_permission('content.moderate')
         or exists (select 1 from public.posts p
                    where p.id = post_id and p.community_id is not null
                      and public.can_moderate_community(p.community_id)));

-- ---------- Views ----------
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
left join public.communities c on c.id = p.community_id;

create or replace view public.community_details with (security_invoker = true) as
select c.id, c.name, c.description, c.rules, c.icon_url, c.banner_url, c.owner_id,
       c.privacy, c.member_count, c.created_at,
       m.role as my_role, m.status as my_status
from public.communities c
left join public.community_members m
  on m.community_id = c.id and m.user_id = auth.uid();

create or replace view public.community_member_details with (security_invoker = true) as
select m.community_id, m.user_id, m.role, m.status, m.joined_at,
       pr.username, pr.display_name, pr.avatar_url
from public.community_members m
join public.profiles pr on pr.id = m.user_id and pr.status = 'active';

grant select on public.feed_posts, public.community_details,
  public.community_member_details to authenticated;

-- ---------- Storage ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('community-media', 'community-media', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "community_media_own_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'community-media'
              and (storage.foldername(name))[1] = auth.uid()::text
              and public.is_active_user());
create policy "community_media_own_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'community-media' and (storage.foldername(name))[1] = auth.uid()::text);
