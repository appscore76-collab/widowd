-- Likes and passes for Discover. Mutual like → the pair's match becomes
-- 'matched'. Members write these only through the SECURITY DEFINER RPCs below.

create table public.likes (
  liker uuid not null references public.profiles (id) on delete cascade,
  liked uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (liker, liked),
  check (liker <> liked)
);
create index likes_liked_idx on public.likes (liked);
alter table public.likes enable row level security;
revoke all on public.likes from anon, authenticated;
grant select on public.likes to authenticated;
-- Members see only their own outgoing likes. Incoming likes ("see who likes
-- you") stay hidden — that is a Plus feature for later.
create policy "Members see their own outgoing likes"
  on public.likes for select to authenticated
  using (liker = (select auth.uid()));

create table public.passes (
  passer uuid not null references public.profiles (id) on delete cascade,
  passed uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (passer, passed),
  check (passer <> passed)
);
create index passes_passer_idx on public.passes (passer);
alter table public.passes enable row level security;
revoke all on public.passes from anon, authenticated;
grant select on public.passes to authenticated;
create policy "Members see their own passes"
  on public.passes for select to authenticated
  using (passer = (select auth.uid()));

-- Like a member. Records the like; if they already like you, the pair's match
-- becomes 'matched'. Returns whether this created a match. SECURITY DEFINER so
-- it can read the other member's like and update the shared matches row; it
-- validates the caller. Exposed to authenticated only (like the other RPCs,
-- the advisor's "authenticated can execute SECURITY DEFINER" note is expected).
create function public.like_member(target uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  is_match boolean := false;
begin
  if me is null then raise exception 'not signed in'; end if;
  if target = me then raise exception 'cannot like yourself'; end if;
  if not exists (select 1 from public.profiles where id = target and listed) then
    raise exception 'target not available';
  end if;
  insert into public.likes (liker, liked) values (me, target)
    on conflict do nothing;
  if exists (select 1 from public.likes where liker = target and liked = me) then
    is_match := true;
    insert into public.matches (user_a, user_b, status)
      values (least(me, target), greatest(me, target), 'matched')
      on conflict (user_a, user_b) do update set status = 'matched', updated_at = now();
  end if;
  return is_match;
end;
$$;
revoke execute on function public.like_member(uuid) from public, anon;
grant execute on function public.like_member(uuid) to authenticated;

-- Pass on a member. Records the pass and ends the pair's suggestion so it
-- drops out of Discover.
create function public.pass_member(target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  if target = me then raise exception 'cannot pass yourself'; end if;
  insert into public.passes (passer, passed) values (me, target)
    on conflict do nothing;
  update public.matches set status = 'ended', updated_at = now()
    where user_a = least(me, target) and user_b = greatest(me, target)
      and status = 'suggested';
end;
$$;
revoke execute on function public.pass_member(uuid) from public, anon;
grant execute on function public.pass_member(uuid) to authenticated;
