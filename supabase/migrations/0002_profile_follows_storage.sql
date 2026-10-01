-- Phase 2: follows, profile_details view, avatar/banner storage.

-- ---------- Follows ----------
create table public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);
create index follows_following_idx on public.follows(following_id);

alter table public.follows enable row level security;

create policy follows_select on public.follows for select to authenticated
  using (public.is_active_user());
create policy follows_insert on public.follows for insert to authenticated
  with check (follower_id = auth.uid() and public.is_active_user());
create policy follows_delete on public.follows for delete to authenticated
  using (follower_id = auth.uid());

-- ---------- Profile view (runs with the caller's RLS) ----------
create or replace view public.profile_details
with (security_invoker = true) as
select
  p.id, p.username, p.display_name, p.avatar_url, p.banner_url, p.bio,
  p.minecraft_username, p.minecraft_edition, p.links, p.status, p.created_at,
  r.key  as role_key,
  r.name as role_name,
  (select count(*) from public.follows f where f.following_id = p.id) as followers_count,
  (select count(*) from public.follows f where f.follower_id  = p.id) as following_count,
  exists (select 1 from public.follows f
          where f.follower_id = auth.uid() and f.following_id = p.id) as is_following
from public.profiles p
join public.roles r on r.id = p.role_id
where p.status = 'active' or p.id = auth.uid();

grant select on public.profile_details to authenticated;

-- ---------- Storage ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars', 'avatars', true, 2097152, array['image/jpeg','image/png','image/webp']),
  ('banners', 'banners', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Files live under "<user_id>/..."; users can only write inside their own folder.
create policy "own_folder_insert" on storage.objects for insert to authenticated
  with check (
    bucket_id in ('avatars', 'banners')
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_active_user()
  );
create policy "own_folder_update" on storage.objects for update to authenticated
  using (bucket_id in ('avatars', 'banners') and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id in ('avatars', 'banners') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own_folder_delete" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars', 'banners') and (storage.foldername(name))[1] = auth.uid()::text);
