-- Paginate the conversations list: my_conversations() gains limit/offset.
-- Replaces the no-argument version.

create or replace function public.my_conversations(
  p_limit integer default 20,
  p_offset integer default 0
)
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
  order by coalesce(c.last_message_at, c.created_at) desc
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
$$;
revoke execute on function public.my_conversations(integer, integer)
  from public, anon;
grant execute on function public.my_conversations(integer, integer) to authenticated;

-- Drop the previous no-argument version.
drop function if exists public.my_conversations();
