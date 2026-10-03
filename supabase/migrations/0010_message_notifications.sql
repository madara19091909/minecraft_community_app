-- MC push-ready message notifications.
-- The existing in-app notification system already uses Realtime; this adds
-- a notification row for every other member when a new chat message arrives.

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check check (type in (
  'like', 'comment', 'follow', 'community_request', 'community_approved',
  'community_added', 'role_change', 'message', 'system'
));

create or replace function public.notify_message()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, actor_id, type, message)
  select cm.user_id,
         new.sender_id,
         'message',
         case
           when new.media_path is not null and char_length(btrim(new.content)) = 0
             then 'sent you a photo'
           when char_length(btrim(new.content)) > 0
             then left(new.content, 300)
           else 'sent you a message'
         end
  from public.conversation_members cm
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> new.sender_id;
  return null;
end $$;

drop trigger if exists messages_notify on public.messages;
create trigger messages_notify
after insert on public.messages
for each row execute function public.notify_message();
