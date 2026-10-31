-- Initial widowd schema: member profiles, system match suggestions,
-- verification records and the profile-photos bucket.
--
-- Members only ever write their own profile's editable columns and their own
-- photos. Matches, Plus status and verification badges are written by the
-- database itself or by Edge Functions using the service role.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) between 1 and 40),
  birth_year smallint check (birth_year between 1900 and 2100),
  gender text check (gender in ('woman', 'man', 'nonbinary')),
  interested_in text[] not null default '{}'
    check (interested_in <@ array['woman', 'man', 'nonbinary']),
  city text check (char_length(city) <= 80),
  bio text check (char_length(bio) <= 1000),
  -- Object key in the profile-photos bucket, always under "<id>/".
  photo_path text check (photo_path like id::text || '/%'),
  plus_expires_at timestamptz,
  id_verified boolean not null default false,
  photo_verified boolean not null default false,
  -- A profile is shown to other members once it has everything matching needs.
  listed boolean generated always as (
    display_name is not null
    and birth_year is not null
    and gender is not null
    and cardinality(interested_in) > 0
    and photo_path is not null
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_listed_created_at_idx on public.profiles (created_at desc) where listed;

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

-- Every new account gets an empty profile row to fill in.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

insert into public.profiles (id) select id from auth.users on conflict (id) do nothing;

alter table public.profiles enable row level security;

-- Column privileges keep plus_expires_at private and let members change only
-- what they can edit in the app.
revoke all on public.profiles from anon, authenticated;
grant select (
  id, display_name, birth_year, gender, interested_in, city, bio, photo_path,
  id_verified, photo_verified, listed, created_at
) on public.profiles to authenticated;
grant update (
  display_name, birth_year, gender, interested_in, city, bio, photo_path
) on public.profiles to authenticated;

create policy "Members see listed profiles and their own"
  on public.profiles for select to authenticated
  using (
    (select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)) = false
    and (listed or id = (select auth.uid()))
  );

create policy "Members update their own profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- matches
-- ---------------------------------------------------------------------------

-- One row per pair, stored with user_a < user_b. The system creates rows as
-- 'suggested'; create-video-call treats 'matched' as an active match.
create table public.matches (
  id bigint generated always as identity primary key,
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'suggested'
    check (status in ('suggested', 'matched', 'ended')),
  score real not null default 0,
  reasons text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (user_a < user_b),
  unique (user_a, user_b)
);

create index matches_user_b_idx on public.matches (user_b);

create trigger matches_set_updated_at
  before update on public.matches
  for each row execute function private.set_updated_at();

alter table public.matches enable row level security;

revoke all on public.matches from anon, authenticated;
grant select on public.matches to authenticated;

create policy "Members see their own matches"
  on public.matches for select to authenticated
  using (user_a = (select auth.uid()) or user_b = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- verifications (written by start-verification and didit-webhook)
-- ---------------------------------------------------------------------------

create table public.verifications (
  session_id text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('id', 'photo')),
  status text not null,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);

create index verifications_user_id_idx on public.verifications (user_id);

alter table public.verifications enable row level security;

revoke all on public.verifications from anon, authenticated;
grant select on public.verifications to authenticated;

create policy "Members see their own verifications"
  on public.verifications for select to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- System match suggestions
-- ---------------------------------------------------------------------------

-- Suggests up to `how_many` new people for one member: listed, mutually
-- interested in each other's gender, within 15 years of age, and not already
-- paired. Closer age, the same city and verification badges rank higher.
create function private.suggest_matches_for(member uuid, how_many int default 3)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  added int;
begin
  with me as (
    select * from public.profiles where id = member and listed
  ),
  candidates as (
    select
      p.id,
      abs(p.birth_year - me.birth_year) as age_gap,
      p.city is not null and me.city is not null
        and lower(trim(p.city)) = lower(trim(me.city)) as same_city,
      p.city,
      p.id_verified,
      p.photo_verified
    from me
    join public.profiles p
      on p.listed
      and p.id <> me.id
      and p.gender = any (me.interested_in)
      and me.gender = any (p.interested_in)
      and abs(p.birth_year - me.birth_year) <= 15
    where not exists (
      select 1 from public.matches m
      where m.user_a = least(me.id, p.id) and m.user_b = greatest(me.id, p.id)
    )
  ),
  ranked as (
    select
      id,
      (1.0 - age_gap / 30.0)
        + case when same_city then 0.5 else 0 end
        + case when id_verified then 0.1 else 0 end
        + case when photo_verified then 0.1 else 0 end as score,
      array_remove(array[
        case when same_city then 'Also lives in ' || trim(city) end,
        case when age_gap <= 5 then 'Close to you in age' end,
        case when id_verified then 'ID verified' end,
        case when photo_verified then 'Photo verified' end
      ], null) as reasons
    from candidates
    order by score desc, random()
    limit how_many
  )
  insert into public.matches (user_a, user_b, score, reasons)
  select least(member, id), greatest(member, id), score, reasons
  from ranked
  on conflict (user_a, user_b) do nothing;

  get diagnostics added = row_count;
  return added;
end;
$$;

-- Tops up suggestions for every listed member; scheduled daily below.
create function private.suggest_matches_for_everyone(how_many int default 3)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  member uuid;
  total int := 0;
begin
  for member in select id from public.profiles where listed loop
    total := total + private.suggest_matches_for(member, how_many);
  end loop;
  return total;
end;
$$;

-- A member gets their first suggestions as soon as their profile is listed.
create function private.suggest_when_listed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.listed and (tg_op = 'INSERT' or not old.listed) then
    perform private.suggest_matches_for(new.id);
  end if;
  return new;
end;
$$;

create trigger profiles_suggest_when_listed
  after insert or update of display_name, birth_year, gender, interested_in, photo_path
  on public.profiles
  for each row execute function private.suggest_when_listed();

revoke all on all functions in schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- profile-photos bucket
-- ---------------------------------------------------------------------------

-- Private bucket; the app shows photos through signed URLs. 2 MB matches
-- Didit's limit for the Face Match reference photo.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', false, 2097152,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "Members upload photos to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Members replace their own photos"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Members delete their own photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Members see their own photos and listed members' photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and (select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)) = false
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1 from public.profiles p
        where p.photo_path = storage.objects.name and p.listed
      )
    )
  );

create index profiles_photo_path_idx on public.profiles (photo_path) where listed;
