// Creates a short-lived, private, unrecorded Daily room for two matched users
// and returns a meeting token for each of them.
//
// Request:  POST { "otherUserId": "<uuid>" } with the caller's session JWT
//           (supabase.functions.invoke('create-video-call', { body: { otherUserId } })).
// Response: { roomName, roomUrl, expiresAt, tokens: { [userId]: token } }
//
// Secrets (supabase secrets set ...): DAILY_API_KEY, DAILY_DOMAIN.
// DAILY_API_KEY is only ever sent to api.daily.co and never appears in a response.
//
// Expected schema (adjust the queries below if yours differs):
//   profiles(id uuid = auth.users.id, display_name text, plus_expires_at timestamptz)
//   matches(user_a uuid, user_b uuid, status text)  -- status 'matched' while active

import { withSupabase } from 'npm:@supabase/server@1.9.2'

const DAILY_API = 'https://api.daily.co/v1'
// Longest a call can last. The room and both tokens expire at this point and
// anyone still in the call is removed.
const CALL_MAX_MINUTES = 60

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const json = (body: unknown, status = 200) => Response.json(body, { status })

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

    const apiKey = Deno.env.get('DAILY_API_KEY')
    const domain = Deno.env.get('DAILY_DOMAIN')?.replace(/\.daily\.co$/, '')
    if (!apiKey || !domain) {
      console.error('DAILY_API_KEY or DAILY_DOMAIN is not set')
      return json({ error: 'not_configured' }, 500)
    }

    // Confirm the session against Auth rather than trusting the JWT alone, so a
    // deleted or anonymous user can't start a call with a still-valid token.
    const { data: { user }, error: userError } = await ctx.supabase.auth.getUser()
    if (userError || !user || user.is_anonymous) return json({ error: 'not_signed_in' }, 401)
    const callerId = user.id

    let otherUserId: unknown
    try {
      ;({ otherUserId } = await req.json())
    } catch {
      return json({ error: 'invalid_body' }, 400)
    }
    if (typeof otherUserId !== 'string' || !UUID_RE.test(otherUserId) || otherUserId === callerId) {
      return json({ error: 'invalid_other_user' }, 400)
    }

    // supabaseAdmin bypasses RLS, so every query is filtered to these two users.
    const db = ctx.supabaseAdmin

    const { data: profiles, error: profilesError } = await db
      .from('profiles')
      .select('id, display_name, plus_expires_at')
      .in('id', [callerId, otherUserId])
    if (profilesError) {
      console.error('profiles lookup failed', profilesError)
      return json({ error: 'lookup_failed' }, 500)
    }
    const caller = profiles?.find((p) => p.id === callerId)
    const other = profiles?.find((p) => p.id === otherUserId)

    const isPlus = !!caller?.plus_expires_at && new Date(caller.plus_expires_at) > new Date()
    if (!isPlus) return json({ error: 'plus_required' }, 403)

    const { data: match, error: matchError } = await db
      .from('matches')
      .select('user_a')
      .eq('status', 'matched')
      .or(
        `and(user_a.eq.${callerId},user_b.eq.${otherUserId}),` +
          `and(user_a.eq.${otherUserId},user_b.eq.${callerId})`,
      )
      .limit(1)
      .maybeSingle()
    if (matchError) {
      console.error('match lookup failed', matchError)
      return json({ error: 'lookup_failed' }, 500)
    }
    if (!match || !other) return json({ error: 'not_matched' }, 403)

    const exp = Math.floor(Date.now() / 1000) + CALL_MAX_MINUTES * 60

    const daily = async (path: string, body: unknown) => {
      const res = await fetch(`${DAILY_API}${path}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      if (!res.ok) {
        // Log Daily's message for debugging; the app only sees a generic error.
        console.error(`Daily ${path} failed`, res.status, await res.text())
        return null
      }
      return await res.json()
    }

    // Recording stays off: enable_recording is left unset on the room and tokens,
    // and neither participant is an owner, so neither can turn it on.
    const room = await daily('/rooms', {
      name: `call-${crypto.randomUUID()}`,
      privacy: 'private',
      properties: {
        exp,
        eject_at_room_exp: true,
        max_participants: 2,
      },
    })
    if (!room?.name || !room?.url) return json({ error: 'room_create_failed' }, 502)
    if (new URL(room.url).hostname !== `${domain}.daily.co`) {
      console.error('Daily room created outside DAILY_DOMAIN', room.url)
      return json({ error: 'room_create_failed' }, 502)
    }

    const tokenFor = (userId: string, userName: string | null) =>
      daily('/meeting-tokens', {
        properties: {
          room_name: room.name,
          user_id: userId,
          user_name: userName ?? undefined,
          exp,
          eject_at_token_exp: true,
          is_owner: false,
          start_cloud_recording: false,
        },
      })

    const [callerToken, otherToken] = await Promise.all([
      tokenFor(callerId, caller!.display_name),
      tokenFor(otherUserId, other.display_name),
    ])
    if (!callerToken?.token || !otherToken?.token) return json({ error: 'token_create_failed' }, 502)

    return json({
      roomName: room.name,
      roomUrl: room.url,
      expiresAt: new Date(exp * 1000).toISOString(),
      tokens: {
        [callerId]: callerToken.token,
        [otherUserId]: otherToken.token,
      },
    })
  }),
}
