-- Push notification device tokens. One row per device FCM token. Members never
-- write this table directly; they call the save_device_token /
-- delete_device_token RPCs. Edge Functions (service role) read it to send push.

create table public.device_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index device_tokens_user_id_idx on public.device_tokens (user_id);

create trigger device_tokens_set_updated_at
  before update on public.device_tokens
  for each row execute function private.set_updated_at();

alter table public.device_tokens enable row level security;

-- Members may read their own tokens (e.g. a future "your devices" screen).
-- All writes go through the SECURITY DEFINER RPCs below, so no insert/update/
-- delete grants to authenticated. Service role bypasses RLS.
revoke all on public.device_tokens from anon, authenticated;
grant select on public.device_tokens to authenticated;

create policy "Members see their own device tokens"
  on public.device_tokens for select to authenticated
  using (user_id = (select auth.uid()));

-- Saves this device's token for the signed-in member, reassigning it from any
-- previous owner (same device, different account). SECURITY DEFINER so it can
-- clear another member's stale row; it validates the caller itself. Exposed to
-- authenticated as an RPC (never anon). The security advisor flags
-- "authenticated can execute SECURITY DEFINER" for this and delete_device_token
-- below; that is intentional — these are member-facing RPCs that check
-- auth.uid(), and the reassigning upsert needs definer rights to clear a stale
-- row owned by a different account.
create function public.save_device_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  if p_platform not in ('android', 'ios', 'web') then
    raise exception 'invalid platform';
  end if;
  if p_token is null or char_length(p_token) not between 1 and 4096 then
    raise exception 'invalid token';
  end if;
  delete from public.device_tokens where token = p_token;
  insert into public.device_tokens (token, user_id, platform)
  values (p_token, auth.uid(), p_platform);
end;
$$;

revoke execute on function public.save_device_token(text, text) from public, anon;
grant execute on function public.save_device_token(text, text) to authenticated;

-- Removes one of the caller's own tokens (sign-out).
create function public.delete_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.device_tokens
  where token = p_token and user_id = auth.uid();
end;
$$;

revoke execute on function public.delete_device_token(text) from public, anon;
grant execute on function public.delete_device_token(text) to authenticated;
