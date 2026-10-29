// Gives the caller a meeting token for a short-lived, private, unrecorded Daily
// room shared with one matched user. Each participant calls this function
// themselves and only ever receives their own token.
//
// Request:  POST { "otherUserId": "<uuid>" } with the caller's session JWT
//           (supabase.functions.invoke('create-video-call', { body: { otherUserId } })).
// Response: { roomName, roomUrl, expiresAt, token }
//
// The first call for a pair creates the room, which requires the caller to be a
// Plus member. A matched partner calling while that room is still open joins it.
//
// Secrets (supabase secrets set ...): DAILY_API_KEY, DAILY_DOMAIN.
// DAILY_API_KEY is only ever sent to api.daily.co and never appears in a response.
//
// Expected schema (adjust the queries below if yours differs):
//   profiles(id uuid = auth.users.id, display_name text, plus_expires_at timestamptz)
//   matches(user_a uuid, user_b uuid, status text)  -- status 'matched' while active

import { withSupabase } from 'npm:@supabase/server@1.9.2'

const DAILY_API = 'https://api.daily.co/v1'
// Longest a call can last. The room and every token expire at this point and
// anyone still in the call is removed.
const CALL_MAX_MINUTES = 60

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const json = (body: unknown, status = 200) => Response.json(body, { status })

type DailyRoom = { name: string; url: string; config?: Record<string, unknown> }

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
    // deleted or anonymous user can't join a call with a still-valid token.
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
    if (!match) return json({ error: 'not_matched' }, 403)

    const { data: caller, error: callerError } = await db
      .from('profiles')
      .select('display_name, plus_expires_at')
      .eq('id', callerId)
      .maybeSingle()
    if (callerError) {
      console.error('profile lookup failed', callerError)
      return json({ error: 'lookup_failed' }, 500)
    }
    const isPlus = !!caller?.plus_expires_at && new Date(caller.plus_expires_at) > new Date()

    const daily = async (method: string, path: string, body?: unknown) => {
      const res = await fetch(`${DAILY_API}${path}`, {
        method,
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
      })
      const data = await res.json().catch(() => null)
      // Log Daily's message for debugging; the app only sees a generic error.
      if (!res.ok && res.status !== 404) console.error(`Daily ${method} ${path} failed`, res.status, data)
      return { status: res.status, data }
    }

    // One room name per pair, derived with the API key so it can't be guessed
    // from user IDs. Both participants resolve to the same room.
    const pair = [callerId, otherUserId].sort().join(':')
    const hmacKey = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(apiKey),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    )
    const digest = new Uint8Array(await crypto.subtle.sign('HMAC', hmacKey, new TextEncoder().encode(pair)))
    const roomName = 'call-' + Array.from(digest.slice(0, 16), (b) => b.toString(16).padStart(2, '0')).join('')

    const now = Math.floor(Date.now() / 1000)
    const getOpenRoom = async (): Promise<DailyRoom | null> => {
      const { status, data } = await daily('GET', `/rooms/${roomName}`)
      if (status !== 200) return null
      const exp = Number(data?.config?.exp)
      if (Number.isFinite(exp) && exp > now) return data
      // The last call for this pair has ended; clear the old room so a new one can take the name.
      await daily('DELETE', `/rooms/${roomName}`)
      return null
    }

    let room = await getOpenRoom()
    if (!room) {
      if (!isPlus) return json({ error: 'plus_required' }, 403)
      const created = await daily('POST', '/rooms', {
        name: roomName,
        privacy: 'private',
        properties: {
          exp: now + CALL_MAX_MINUTES * 60,
          eject_at_room_exp: true,
          max_participants: 2,
        },
      })
      // If the partner created the room at the same moment, use theirs.
      room = created.status === 200 ? created.data : await getOpenRoom()
    }
    if (!room?.name || !room?.url) return json({ error: 'room_unavailable' }, 502)

    if (new URL(room.url).hostname !== `${domain}.daily.co`) {
      console.error('Daily room is outside DAILY_DOMAIN', room.url)
      return json({ error: 'room_unavailable' }, 502)
    }
    // Recording must stay off. Nothing here enables it, so refuse to hand out a
    // token if the room says otherwise (for example, a domain default leaking in).
    if (room.config?.enable_recording) {
      console.error('Daily room has recording enabled; refusing to issue a token', room.name)
      return json({ error: 'room_unavailable' }, 502)
    }
    const exp = Number(room.config?.exp)
    if (!Number.isFinite(exp)) {
      console.error('Daily room has no expiry; refusing to issue a token', room.name)
      return json({ error: 'room_unavailable' }, 502)
    }

    // A token is scoped to this room and this user, expires with the room, and
    // carries no owner rights, so its holder can't start a recording.
    const { status, data: token } = await daily('POST', '/meeting-tokens', {
      properties: {
        room_name: room.name,
        user_id: callerId,
        user_name: caller?.display_name ?? undefined,
        exp,
        eject_at_token_exp: true,
        is_owner: false,
        start_cloud_recording: false,
      },
    })
    if (status !== 200 || !token?.token) return json({ error: 'token_create_failed' }, 502)

    return json({
      roomName: room.name,
      roomUrl: room.url,
      expiresAt: new Date(exp * 1000).toISOString(),
      token: token.token,
    })
  }),
}
