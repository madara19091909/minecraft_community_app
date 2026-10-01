-- Phase 1: roles, permissions, profiles, RLS.
-- Users are provisioned by admins (no public sign-up). A trigger creates a
-- 'pending' profile for every new auth user; an admin must set it to 'active'.

create extension if not exists "pgcrypto";

create type public.account_status as enum ('pending', 'active', 'suspended', 'banned');

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ---------- RBAC ----------
create table public.roles (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  rank int not null,              -- higher = more powerful
  created_at timestamptz not null default now()
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  description text,
  created_at timestamptz not null default now()
);

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

-- ---------- Profiles ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,24}$'),
  display_name text,
  avatar_url text,
  banner_url text,
  bio text check (char_length(bio) <= 300),
  minecraft_username text,
  minecraft_edition text check (minecraft_edition in ('java', 'bedrock')),
  links jsonb not null default '{}'::jsonb,
  role_id uuid not null references public.roles(id),
  status public.account_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_role_idx on public.profiles(role_id);
create index profiles_status_idx on public.profiles(status);
create index profiles_minecraft_username_idx on public.profiles(lower(minecraft_username));

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------- Security helpers (SECURITY DEFINER avoids RLS recursion) ----------
create or replace function public.is_active_user()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and status = 'active');
$$;

create or replace function public.has_permission(p_key text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from profiles pr
    join role_permissions rp on rp.role_id = pr.role_id
    join permissions pm on pm.id = rp.permission_id
    where pr.id = auth.uid() and pr.status = 'active' and pm.key = p_key
  );
$$;

create or replace function public.role_rank(p_user uuid)
returns int language sql stable security definer set search_path = public as $$
  select r.rank from profiles p join roles r on r.id = p.role_id where p.id = p_user;
$$;

-- Users can never change their own role/status; managers can only touch users
-- ranked strictly below themselves and cannot grant a role above their own.
create or replace function public.guard_profile_privileged_columns()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  actor_rank int;
  new_role_rank int;
begin
  if new.role_id is distinct from old.role_id or new.status is distinct from old.status then
    if auth.uid() is null then return new; end if; -- service/SQL editor context
    if not (public.has_permission('users.manage') or public.has_permission('roles.manage')) then
      raise exception 'not allowed to change role or status';
    end if;
    actor_rank := public.role_rank(auth.uid());
    select rank into new_role_rank from roles where id = new.role_id;
    if old.id = auth.uid() then
      raise exception 'cannot change your own role or status';
    end if;
    if public.role_rank(old.id) >= actor_rank or new_role_rank >= actor_rank then
      if actor_rank < (select rank from roles where key = 'owner') then
        raise exception 'insufficient rank';
      end if;
    end if;
  end if;
  return new;
end $$;

create trigger profiles_guard before update on public.profiles
  for each row execute function public.guard_profile_privileged_columns();

-- New auth user -> pending member profile. Username can be passed in
-- raw_user_meta_data when the admin creates the user; otherwise derived.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  uname text;
begin
  uname := lower(regexp_replace(
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    '[^a-zA-Z0-9_]', '', 'g'));
  if char_length(uname) < 3 then uname := 'user_' || substr(new.id::text, 1, 8); end if;
  if exists (select 1 from profiles where username = uname) then
    uname := left(uname, 15) || '_' || substr(new.id::text, 1, 6);
  end if;
  insert into profiles (id, username, display_name, role_id, status)
  values (new.id, uname, new.raw_user_meta_data->>'display_name',
          (select id from roles where key = 'member'), 'pending');
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- RLS ----------
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.profiles enable row level security;

-- Everyone logged in may read own profile (needed for the status gate);
-- only active users may read other profiles.
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_active_user());

create policy profiles_update_own on public.profiles for update to authenticated
  using (id = auth.uid() and status = 'active')
  with check (id = auth.uid());

create policy profiles_update_admin on public.profiles for update to authenticated
  using (public.has_permission('users.manage') or public.has_permission('roles.manage'))
  with check (public.has_permission('users.manage') or public.has_permission('roles.manage'));

-- No INSERT/DELETE policies: profiles are created by trigger / removed via auth cascade.

create policy roles_select on public.roles for select to authenticated using (true);
create policy permissions_select on public.permissions for select to authenticated
  using (public.is_active_user());
create policy role_permissions_select on public.role_permissions for select to authenticated
  using (public.is_active_user());

create policy roles_owner_write on public.roles for all to authenticated
  using (public.has_permission('roles.manage')) with check (public.has_permission('roles.manage'));
create policy role_permissions_write on public.role_permissions for all to authenticated
  using (public.has_permission('roles.manage')) with check (public.has_permission('roles.manage'));

-- ---------- Seed ----------
insert into public.roles (key, name, rank) values
  ('member', 'Member', 10), ('creator', 'Creator', 20), ('staff', 'Staff', 30),
  ('developer', 'Developer', 40), ('moderator', 'Moderator', 50),
  ('admin', 'Admin', 90), ('owner', 'Owner', 100);

insert into public.permissions (key, description) values
  ('posts.create', 'Create posts'), ('comments.create', 'Comment'),
  ('messages.send', 'Send direct messages'), ('communities.join', 'Join communities'),
  ('content.moderate', 'Remove posts and comments'), ('reports.review', 'Review reports'),
  ('communities.manage', 'Manage communities'), ('users.manage', 'Suspend/ban users'),
  ('roles.manage', 'Change roles'), ('announcements.send', 'Send announcements'),
  ('creator.features', 'Creator-only features');

-- role -> permission matrix
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.key in (
  select unnest(case r.key
    when 'member' then array['posts.create','comments.create','messages.send','communities.join']
    when 'creator' then array['posts.create','comments.create','messages.send','communities.join','creator.features']
    when 'staff' then array['posts.create','comments.create','messages.send','communities.join']
    when 'developer' then array['posts.create','comments.create','messages.send','communities.join']
    when 'moderator' then array['posts.create','comments.create','messages.send','communities.join','content.moderate','reports.review','communities.manage']
    when 'admin' then array['posts.create','comments.create','messages.send','communities.join','creator.features','content.moderate','reports.review','communities.manage','users.manage','announcements.send']
    when 'owner' then array['posts.create','comments.create','messages.send','communities.join','creator.features','content.moderate','reports.review','communities.manage','users.manage','roles.manage','announcements.send']
  end)
);
