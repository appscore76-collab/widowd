-- Chat: 1:1 messaging between matched members, with per-conversation read
-- state, unread counts and blocking (design screens 08–09).
--
-- A conversation exists only for a 'matched' pair and is created automatically
-- when a match becomes 'matched'. Members write only through the SECURITY
-- DEFINER RPCs below; blocking hides a conversation and its messages for both
-- people. Messages and conversations are published for Realtime so the app
-- gets new messages and read receipts live.

-- ---------------------------------------------------------------------------
-- blocks
-- ---------------------------------------------------------------------------

create table public.blocks (
  blocker uuid not null references public.profiles (id) on delete cascade,
  blocked uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
create index blocks_blocked_idx on public.blocks (blocked);

alter table public.blocks enable row level security;
revoke all on public.blocks from anon, authenticated;
grant select on public.blocks to authenticated;
-- Members see only their own outgoing blocks.
create policy "Members see their own blocks"
  on public.blocks for select to authenticated
  using (blocker = (select auth.uid()));

-- True if either member has blocked the other. Plain helper used only inside
-- the SECURITY DEFINER functions below (which already run with owner rights),
-- so it needs no execute grant of its own.
create function private.block_exists(a uuid, b uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks
    where (blocker = a and blocked = b) or (blocker = b and blocked = a)
  );
$$;
revoke execute on function private.block_exists(uuid, uuid)
  from public, anon, authenticated;

-- Whether the caller may see a conversation between user_a and user_b: they
-- must be one of the pair and neither may have blocked the other. SECURITY
-- DEFINER so it can check blocks in both directions (members can't read
-- incoming blocks); it returns false for anyone who isn't a participant, so it
-- reveals nothing about strangers. Used by the conversations RLS policy.
create function public.conversation_visible(p_user_a uuid, p_user_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (p_user_a = auth.uid() or p_user_b = auth.uid())
    and not private.block_exists(p_user_a, p_user_b);
$$;
revoke execute on function public.conversation_visible(uuid, uuid)
  from public, anon;
grant execute on function public.conversation_visible(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- conversations  (one row per matched pair, stored with user_a < user_b)
-- ---------------------------------------------------------------------------

create table public.conversations (
  id bigint generated always as identity primary key,
  match_id bigint not null references public.matches (id) on delete cascade
    unique,
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid not null references public.profiles (id) on delete cascade,
  -- When each participant last read the conversation (unread + read receipts).
  a_last_read_at timestamptz,
  b_last_read_at timestamptz,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  check (user_a < user_b),
  unique (user_a, user_b)
);
create index conversations_user_a_idx on public.conversations (user_a);
create index conversations_user_b_idx on public.conversations (user_b);

alter table public.conversations enable row level security;
revoke all on public.conversations from anon, authenticated;
grant select on public.conversations to authenticated;
create policy "Members see their own unblocked conversations"
  on public.conversations for select to authenticated
  using (
    ((select auth.jwt()) ->> 'is_anonymous') is distinct from 'true'
    and public.conversation_visible(user_a, user_b)
  );

-- ---------------------------------------------------------------------------
-- messages
-- ---------------------------------------------------------------------------

create table public.messages (
  id bigint generated always as identity primary key,
  conversation_id bigint not null references public.conversations (id)
    on delete cascade,
  sender uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index messages_conversation_created_idx
  on public.messages (conversation_id, created_at);

alter table public.messages enable row level security;
revoke all on public.messages from anon, authenticated;
grant select on public.messages to authenticated;
-- A member sees a message only if they can see its conversation. The subquery
-- is itself filtered by the conversations policy above, so blocked or
-- non-participant conversations yield no row and the message stays hidden.
-- Members never insert directly — send_message() does that.
create policy "Members see messages in their conversations"
  on public.messages for select to authenticated
  using (
    exists (
      select 1 from public.conversations c where c.id = conversation_id
    )
  );

-- ---------------------------------------------------------------------------
-- Conversation creation: when a match becomes 'matched', open its conversation
-- ---------------------------------------------------------------------------

create function private.create_conversation_on_match()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'matched' then
    insert into public.conversations (match_id, user_a, user_b)
      values (new.id, new.user_a, new.user_b)
      on conflict (match_id) do nothing;
  end if;
  return new;
end;
$$;
revoke execute on function private.create_conversation_on_match()
  from public, anon, authenticated;

create trigger matches_create_conversation
  after insert or update of status on public.matches
  for each row execute function private.create_conversation_on_match();

-- Backfill conversations for pairs that are already matched.
insert into public.conversations (match_id, user_a, user_b)
select id, user_a, user_b from public.matches where status = 'matched'
on conflict (match_id) do nothing;

-- ---------------------------------------------------------------------------
-- Member RPCs (public, SECURITY DEFINER, authenticated only). The advisor's
-- "authenticated can execute SECURITY DEFINER" note is expected here, as for
-- the likes/passes and device-token RPCs.
-- ---------------------------------------------------------------------------

-- Send a message in a conversation the caller is part of. Requires the pair to
-- be 'matched' and not blocked. Records it, bumps last_message_at and marks the
-- conversation read for the sender. Returns the new message id.
create function public.send_message(p_conversation_id bigint, p_body text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  conv public.conversations%rowtype;
  match_status text;
  clean text := btrim(p_body);
  new_id bigint;
begin
  if me is null then raise exception 'not signed in'; end if;
  if clean = '' then raise exception 'message is empty'; end if;
  if char_length(clean) > 4000 then raise exception 'message too long'; end if;

  select * into conv from public.conversations where id = p_conversation_id;
  if not found then raise exception 'conversation not found'; end if;
  if me <> conv.user_a and me <> conv.user_b then
    raise exception 'not your conversation';
  end if;
  if private.block_exists(conv.user_a, conv.user_b) then
    raise exception 'conversation unavailable';
  end if;

  select status into match_status from public.matches where id = conv.match_id;
  if match_status is distinct from 'matched' then
    raise exception 'not matched';
  end if;

  insert into public.messages (conversation_id, sender, body)
    values (p_conversation_id, me, clean)
    returning id into new_id;

  update public.conversations set
    last_message_at = now(),
    a_last_read_at = case when me = user_a then now() else a_last_read_at end,
    b_last_read_at = case when me = user_b then now() else b_last_read_at end
  where id = p_conversation_id;

  return new_id;
end;
$$;
revoke execute on function public.send_message(bigint, text) from public, anon;
grant execute on function public.send_message(bigint, text) to authenticated;

-- Mark the caller's side of a conversation read (clears their unread count and
-- lets the other person see "Seen").
create function public.mark_conversation_read(p_conversation_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  update public.conversations set
    a_last_read_at = case when me = user_a then now() else a_last_read_at end,
    b_last_read_at = case when me = user_b then now() else b_last_read_at end
  where id = p_conversation_id and (user_a = me or user_b = me);
end;
$$;
revoke execute on function public.mark_conversation_read(bigint)
  from public, anon;
grant execute on function public.mark_conversation_read(bigint) to authenticated;

-- Block a member: their conversation and its messages disappear for both
-- people. Unblock reverses it.
create function public.block_member(target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  if target = me then raise exception 'cannot block yourself'; end if;
  insert into public.blocks (blocker, blocked) values (me, target)
    on conflict do nothing;
end;
$$;
revoke execute on function public.block_member(uuid) from public, anon;
grant execute on function public.block_member(uuid) to authenticated;

create function public.unblock_member(target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  delete from public.blocks where blocker = me and blocked = target;
end;
$$;
revoke execute on function public.unblock_member(uuid) from public, anon;
grant execute on function public.unblock_member(uuid) to authenticated;

-- The caller's conversations, newest activity first, with the peer's profile,
-- a preview of the last message and the caller's unread count. SECURITY
-- DEFINER so it can read the peer profile, the last message and blocks while
-- staying scoped to the caller's own conversations.
create function public.my_conversations()
returns table (
  conversation_id bigint,
  peer_id uuid,
  display_name text,
  birth_year smallint,
  gender text,
  interested_in text[],
  city text,
  bio text,
  photo_path text,
  id_verified boolean,
  photo_verified boolean,
  listed boolean,
  last_message_body text,
  last_message_at timestamptz,
  last_message_sender uuid,
  unread_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id,
    p.id,
    p.display_name,
    p.birth_year,
    p.gender,
    p.interested_in,
    p.city,
    p.bio,
    p.photo_path,
    p.id_verified,
    p.photo_verified,
    p.listed,
    lm.body,
    lm.created_at,
    lm.sender,
    (
      select count(*)
      from public.messages m
      where m.conversation_id = c.id
        and m.sender <> auth.uid()
        and (
          (case when auth.uid() = c.user_a then c.a_last_read_at
                else c.b_last_read_at end) is null
          or m.created_at > (case when auth.uid() = c.user_a then c.a_last_read_at
                                  else c.b_last_read_at end)
        )
    )::int
  from public.conversations c
  join public.profiles p
    on p.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
  left join lateral (
    select body, created_at, sender
    from public.messages
    where conversation_id = c.id
    order by created_at desc
    limit 1
  ) lm on true
  where (c.user_a = auth.uid() or c.user_b = auth.uid())
    and not private.block_exists(c.user_a, c.user_b)
  order by coalesce(c.last_message_at, c.created_at) desc;
$$;
revoke execute on function public.my_conversations() from public, anon;
grant execute on function public.my_conversations() to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: the app subscribes to new messages and to conversation updates
-- (the peer's last-read, for "Seen"). Full replica identity so update payloads
-- carry the changed columns.
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.conversations;
alter table public.conversations replica identity full;
