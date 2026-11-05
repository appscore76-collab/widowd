-- "Likes you" + match paywall.
-- Free members can see who likes them (likers()); liking back makes a match
-- only when at least one side has active Widowd Plus. plus_expires_at stays
-- unreadable to members — only booleans are exposed.

-- Whether a member has active Widowd Plus. Plain helper used inside the
-- SECURITY DEFINER functions below; no execute grant of its own.
create function private.is_plus(uid uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = uid
      and plus_expires_at is not null
      and plus_expires_at > now()
  );
$$;
revoke execute on function private.is_plus(uuid) from public, anon, authenticated;

-- The caller's own Plus status, so the app can gate Plus-only actions without
-- reading plus_expires_at.
create function public.my_plus_status()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_plus(auth.uid());
$$;
revoke execute on function public.my_plus_status() from public, anon;
grant execute on function public.my_plus_status() to authenticated;

-- People who like the caller ("Likes you"), newest first. Free to view.
-- free_to_like_back is true when that admirer already has Plus (the caller can
-- then match for free); otherwise the caller needs Plus to like back and match.
-- Excludes anyone already matched, anyone the caller passed, blocked pairs and
-- unlisted profiles. SECURITY DEFINER so it can read incoming likes and the
-- admirer's Plus flag, both hidden from members at the table level.
create function public.likers(
  p_limit integer default 24,
  p_offset integer default 0
)
returns table (
  id uuid,
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
  intent text,
  journey text,
  children_count smallint,
  children_ages text,
  children_at_home text,
  open_to_children text,
  ready_for text,
  perfect_sunday text,
  occupation text,
  interests text[],
  free_to_like_back boolean,
  liked_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id, p.display_name, p.birth_year, p.gender, p.interested_in, p.city,
    p.bio, p.photo_path, p.id_verified, p.photo_verified, p.listed, p.intent,
    p.journey, p.children_count, p.children_ages, p.children_at_home,
    p.open_to_children, p.ready_for, p.perfect_sunday, p.occupation,
    p.interests,
    private.is_plus(l.liker) as free_to_like_back,
    l.created_at as liked_at
  from public.likes l
  join public.profiles p on p.id = l.liker
  where l.liked = auth.uid()
    and p.listed
    and not private.block_exists(l.liker, auth.uid())
    and not exists (
      select 1 from public.matches m
      where m.user_a = least(l.liker, auth.uid())
        and m.user_b = greatest(l.liker, auth.uid())
        and m.status = 'matched'
    )
    and not exists (
      select 1 from public.passes pa
      where pa.passer = auth.uid() and pa.passed = l.liker
    )
  order by l.created_at desc
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
$$;
revoke execute on function public.likers(integer, integer) from public, anon;
grant execute on function public.likers(integer, integer) to authenticated;

-- Rework like_member: the match paywall. Returns a status text:
--   'liked'         — recorded interest, no reciprocal like yet
--   'matched'       — mutual like and at least one side has Plus: matched
--   'plus_required' — mutual like but neither side has Plus: no match yet
-- Return type changes (boolean -> text), so drop and recreate.
drop function public.like_member(uuid);
create function public.like_member(target uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  reciprocal boolean;
begin
  if me is null then raise exception 'not signed in'; end if;
  if target = me then raise exception 'cannot like yourself'; end if;
  if not exists (select 1 from public.profiles where id = target and listed) then
    raise exception 'target not available';
  end if;

  reciprocal := exists (
    select 1 from public.likes where liker = target and liked = me
  );

  if reciprocal then
    if private.is_plus(me) or private.is_plus(target) then
      insert into public.likes (liker, liked) values (me, target)
        on conflict do nothing;
      insert into public.matches (user_a, user_b, status)
        values (least(me, target), greatest(me, target), 'matched')
        on conflict (user_a, user_b)
          do update set status = 'matched', updated_at = now();
      return 'matched';
    end if;
    -- Mutual interest, but neither side has Plus: gate the match, record nothing
    -- so the admirer stays in the caller's "Likes you" list to try again later.
    return 'plus_required';
  end if;

  -- No reciprocal like yet: record interest, no match regardless of Plus.
  insert into public.likes (liker, liked) values (me, target)
    on conflict do nothing;
  return 'liked';
end;
$$;
revoke execute on function public.like_member(uuid) from public, anon;
grant execute on function public.like_member(uuid) to authenticated;
