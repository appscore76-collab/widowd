-- Richer profile fields for Discover and the profile screen (design 02/03/05/07):
-- dating intent, widowed journey, children, "ready for"/"perfect Sunday"
-- prompts, occupation and interests. All member-editable on their own profile.

alter table public.profiles
  add column intent text
    check (intent in ('friend', 'casual', 'long', 'marriage', 'unsure')),
  add column journey text
    check (journey in ('under2', '2to5', '5plus', 'prefer_not')),
  add column children_count smallint
    check (children_count between 0 and 5),
  add column children_ages text
    check (children_ages in ('under12', 'teenagers', 'grown_up', 'mixed')),
  add column children_at_home text
    check (children_at_home in ('yes', 'no', 'sometimes')),
  add column open_to_children text
    check (open_to_children in ('yes', 'prefer_not', 'dont_mind')),
  add column ready_for text check (char_length(ready_for) <= 280),
  add column perfect_sunday text check (char_length(perfect_sunday) <= 280),
  add column occupation text check (char_length(occupation) <= 80),
  add column interests text[] not null default '{}'
    check (cardinality(interests) <= 12);

-- Members may read these on listed profiles and write them on their own.
grant select (
  intent, journey, children_count, children_ages, children_at_home,
  open_to_children, ready_for, perfect_sunday, occupation, interests
) on public.profiles to authenticated;
grant update (
  intent, journey, children_count, children_ages, children_at_home,
  open_to_children, ready_for, perfect_sunday, occupation, interests
) on public.profiles to authenticated;
