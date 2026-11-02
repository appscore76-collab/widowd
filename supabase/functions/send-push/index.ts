// Sends a push notification to every device of one member via Firebase Cloud
// Messaging (FCM HTTP v1). Meant to be called server-side only (other Edge
// Functions, DB triggers, cron) — never by members directly — so it is gated
// by a shared secret rather than a member session.
//
// Request:  POST { "userId": "<uuid>", "title": "...", "body": "...",
//                  "data": { "<k>": "<v>" } }   with header
//           x-push-secret: <PUSH_FUNCTION_SECRET>
// Response: { sent, removed, failed }
//
// Looks up public.device_tokens for the member, sends to each token, and
// deletes any token FCM reports as unregistered/invalid.
//
// Secrets (supabase secrets set ... --project-ref gzgrbbeohcerznezawna):
//   PUSH_FUNCTION_SECRET     a long random string; callers send it as
//                            x-push-secret.
//   FIREBASE_SERVICE_ACCOUNT the Firebase service account JSON (one line),
//                            from Firebase console → Project settings →
//                            Service accounts → Generate new private key.
// Neither ever appears in a response.

import { withSupabase } from 'npm:@supabase/server@1.9.2'

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'
const TOKEN_URL = 'https://oauth2.googleapis.com/token'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const json = (body: unknown, status = 200) => Response.json(body, { status })

const b64url = (bytes: Uint8Array) => {
  let s = ''
  for (const b of bytes) s += String.fromCharCode(b)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

const pemToPkcs8 = (pem: string): ArrayBuffer => {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/, '')
    .replace(/-----END [^-]+-----/, '')
    .replace(/\s+/g, '')
  const bin = atob(body)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf.buffer
}

type ServiceAccount = {
  client_email: string
  private_key: string
  project_id: string
}

// Mints a short-lived Google OAuth access token for the FCM scope by signing a
// JWT with the service account key (RS256) and exchanging it.
const getAccessToken = async (sa: ServiceAccount): Promise<string> => {
  const now = Math.floor(Date.now() / 1000)
  const header = b64url(
    new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
  )
  const claims = b64url(
    new TextEncoder().encode(
      JSON.stringify({
        iss: sa.client_email,
        scope: FCM_SCOPE,
        aud: TOKEN_URL,
        iat: now,
        exp: now + 3600,
      }),
    ),
  )
  const signingInput = `${header}.${claims}`
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(sa.private_key.replace(/\\n/g, '\n')),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      key,
      new TextEncoder().encode(signingInput),
    ),
  )
  const assertion = `${signingInput}.${b64url(signature)}`

  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })
  const data = await res.json().catch(() => null)
  if (!res.ok || !data?.access_token) {
    console.error('token exchange failed', res.status, data)
    throw new Error('token_exchange_failed')
  }
  return data.access_token as string
}

export default {
  fetch: withSupabase({ auth: 'none' }, async (req, ctx) => {
    if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

    const secret = Deno.env.get('PUSH_FUNCTION_SECRET')
    const saRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!secret || !saRaw) {
      console.error('PUSH_FUNCTION_SECRET or FIREBASE_SERVICE_ACCOUNT is not set')
      return json({ error: 'not_configured' }, 500)
    }
    // Constant-time-ish check of the shared secret.
    const provided = req.headers.get('x-push-secret') ?? ''
    if (provided.length !== secret.length) {
      return json({ error: 'forbidden' }, 403)
    }
    let same = 0
    for (let i = 0; i < secret.length; i++) {
      same |= provided.charCodeAt(i) ^ secret.charCodeAt(i)
    }
    if (same !== 0) return json({ error: 'forbidden' }, 403)

    let payload: {
      userId?: unknown
      title?: unknown
      body?: unknown
      data?: unknown
    }
    try {
      payload = await req.json()
    } catch {
      return json({ error: 'invalid_body' }, 400)
    }
    const { userId, title, body } = payload
    if (typeof userId !== 'string' || !UUID_RE.test(userId)) {
      return json({ error: 'invalid_user' }, 400)
    }
    if (typeof title !== 'string' || typeof body !== 'string') {
      return json({ error: 'invalid_message' }, 400)
    }
    // FCM data values must be strings.
    const data: Record<string, string> = {}
    if (payload.data && typeof payload.data === 'object') {
      for (const [k, v] of Object.entries(payload.data as object)) {
        data[k] = typeof v === 'string' ? v : JSON.stringify(v)
      }
    }

    let sa: ServiceAccount
    try {
      sa = JSON.parse(saRaw)
    } catch {
      console.error('FIREBASE_SERVICE_ACCOUNT is not valid JSON')
      return json({ error: 'not_configured' }, 500)
    }

    const db = ctx.supabaseAdmin
    const { data: rows, error } = await db
      .from('device_tokens')
      .select('token')
      .eq('user_id', userId)
    if (error) {
      console.error('device_tokens lookup failed', error)
      return json({ error: 'lookup_failed' }, 500)
    }
    const tokens = (rows ?? []).map((r) => r.token as string)
    if (tokens.length === 0) return json({ sent: 0, removed: 0, failed: 0 })

    let accessToken: string
    try {
      accessToken = await getAccessToken(sa)
    } catch {
      return json({ error: 'fcm_auth_failed' }, 502)
    }

    const sendUrl =
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`
    let sent = 0
    const stale: string[] = []
    let failed = 0

    for (const token of tokens) {
      const res = await fetch(sendUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            ...(Object.keys(data).length ? { data } : {}),
          },
        }),
      })
      if (res.ok) {
        sent++
        continue
      }
      const err = await res.json().catch(() => null)
      const code = err?.error?.details?.[0]?.errorCode ?? err?.error?.status
      // Only drop tokens FCM says it no longer knows — never on a generic bad
      // request, so a malformed message can't wipe valid tokens.
      if (res.status === 404 || code === 'UNREGISTERED') {
        stale.push(token)
      } else {
        failed++
        console.error('FCM send failed', res.status, err)
      }
    }

    if (stale.length) {
      const { error: delError } = await db
        .from('device_tokens')
        .delete()
        .in('token', stale)
      if (delError) console.error('stale token cleanup failed', delError)
    }

    return json({ sent, removed: stale.length, failed })
  }),
}
