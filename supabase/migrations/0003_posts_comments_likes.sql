-- Phase 3: posts, media, likes, comments (+ counters, views, storage).

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  content text not null default '' check (char_length(content) <= 2000),
  likes_count int not null default 0,
  comments_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index posts_created_idx on public.posts(created_at desc);
create index posts_author_idx on public.posts(author_id, created_at desc);
create trigger posts_updated_at before update on public.posts
  for each row execute function public.set_updated_at();

create table public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  url text not null,
  storage_path text not null,
  kind text not null default 'image' check (kind in ('image', 'video')),
  position smallint not null default 0 check (position between 0 and 3),
  created_at timestamptz not null default now()
);
create index post_media_post_idx on public.post_media(post_id, position);

create table public.likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create index likes_post_idx on public.likes(post_id);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(btrim(content)) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index comments_post_idx on public.comments(post_id, created_at);
create trigger comments_updated_at before update on public.comments
  for each row execute function public.set_updated_at();

-- ---------- Counters (maintained server-side, never by clients) ----------
create or replace function public.bump_likes_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update posts set likes_count = likes_count + 1 where id = new.post_id;
  else
    update posts set likes_count = greatest(likes_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end $$;
create trigger likes_count_trg after insert or delete on public.likes
  for each row execute function public.bump_likes_count();

create or replace function public.bump_comments_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update posts set comments_count = comments_count + 1 where id = new.post_id;
  else
    update posts set comments_count = greatest(comments_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end $$;
create trigger comments_count_trg after insert or delete on public.comments
  for each row execute function public.bump_comments_count();

-- ---------- Column-level privileges: clients can only write content ----------
revoke insert, update on public.posts from authenticated;
grant insert (author_id, content) on public.posts to authenticated;
grant update (content) on public.posts to authenticated;

revoke insert, update on public.comments from authenticated;
grant insert (post_id, author_id, content) on public.comments to authenticated;
grant update (content) on public.comments to authenticated;

-- ---------- RLS ----------
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;

create policy posts_select on public.posts for select to authenticated
  using (public.is_active_user());
create policy posts_insert on public.posts for insert to authenticated
  with check (author_id = auth.uid() and public.has_permission('posts.create'));
create policy posts_update_own on public.posts for update to authenticated
  using (author_id = auth.uid() and public.is_active_user())
  with check (author_id = auth.uid());
create policy posts_delete on public.posts for delete to authenticated
  using ((author_id = auth.uid() and public.is_active_user())
         or public.has_permission('content.moderate'));

create policy post_media_select on public.post_media for select to authenticated
  using (public.is_active_user());
create policy post_media_insert on public.post_media for insert to authenticated
  with check (exists (select 1 from public.posts p
                      where p.id = post_id and p.author_id = auth.uid())
              and public.has_permission('posts.create'));
create policy post_media_delete on public.post_media for delete to authenticated
  using (exists (select 1 from public.posts p
                 where p.id = post_id and p.author_id = auth.uid())
         or public.has_permission('content.moderate'));

create policy likes_select on public.likes for select to authenticated
  using (public.is_active_user());
create policy likes_insert on public.likes for insert to authenticated
  with check (user_id = auth.uid() and public.is_active_user());
create policy likes_delete on public.likes for delete to authenticated
  using (user_id = auth.uid());

create policy comments_select on public.comments for select to authenticated
  using (public.is_active_user());
create policy comments_insert on public.comments for insert to authenticated
  with check (author_id = auth.uid() and public.has_permission('comments.create'));
create policy comments_update_own on public.comments for update to authenticated
  using (author_id = auth.uid() and public.is_active_user())
  with check (author_id = auth.uid());
create policy comments_delete on public.comments for delete to authenticated
  using ((author_id = auth.uid() and public.is_active_user())
         or public.has_permission('content.moderate'));

-- ---------- Views (security_invoker => caller's RLS applies) ----------
create or replace view public.feed_posts with (security_invoker = true) as
select
  p.id, p.author_id, p.content, p.likes_count, p.comments_count, p.created_at,
  pr.username, pr.display_name, pr.avatar_url,
  r.key as author_role_key,
  coalesce((select json_agg(json_build_object('url', m.url, 'kind', m.kind) order by m.position)
            from public.post_media m where m.post_id = p.id), '[]'::json) as media,
  exists (select 1 from public.likes l
          where l.post_id = p.id and l.user_id = auth.uid()) as liked_by_me
from public.posts p
join public.profiles pr on pr.id = p.author_id and pr.status = 'active'
join public.roles r on r.id = pr.role_id;

create or replace view public.comment_details with (security_invoker = true) as
select c.id, c.post_id, c.author_id, c.content, c.created_at,
       pr.username, pr.display_name, pr.avatar_url
from public.comments c
join public.profiles pr on pr.id = c.author_id and pr.status = 'active';

grant select on public.feed_posts, public.comment_details to authenticated;

-- ---------- Storage ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-media', 'post-media', true, 8388608, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "post_media_own_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'post-media'
              and (storage.foldername(name))[1] = auth.uid()::text
              and public.has_permission('posts.create'));
create policy "post_media_own_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);
