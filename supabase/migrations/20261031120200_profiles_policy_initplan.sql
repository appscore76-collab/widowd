-- Evaluate auth.jwt() once per query instead of once per row.
alter policy "Members see listed profiles and their own"
  on public.profiles
  using (
    ((select auth.jwt()) ->> 'is_anonymous') is distinct from 'true'
    and (listed or id = (select auth.uid()))
  );

alter policy "Members see their own photos and listed members' photos"
  on storage.objects
  using (
    bucket_id = 'profile-photos'
    and ((select auth.jwt()) ->> 'is_anonymous') is distinct from 'true'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1 from public.profiles p
        where p.photo_path = storage.objects.name and p.listed
      )
    )
  );
