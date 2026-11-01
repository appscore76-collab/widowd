-- public.rls_auto_enable() is Supabase's event-trigger function that turns on
-- row-level security for new tables. It only ever runs from its event
-- trigger, so nobody needs to call it through the API.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
