// Starts a Didit verification session for the signed-in member and returns the
// hosted verification URL for the app to open.
//
// Request:  POST { "type": "id" | "photo" } with the caller's session JWT
//           (supabase.functions.invoke('start-verification', { body: { type } })).
// Response: { url }
//
//   id     DIDIT_WORKFLOW_ID_IDCHECK, an ID document check.
//   photo  DIDIT_WORKFLOW_ID_PHOTO, with the member's profile photo sent as the
//          Face Match reference, so Didit confirms the photo shows the member.
//
// The result arrives later at the didit-webhook function, which looks the
// session up in verifications by session_id.
//
// Secrets (supabase secrets set ...): DIDIT_API_KEY, DIDIT_WORKFLOW_ID_IDCHECK,
// DIDIT_WORKFLOW_ID_PHOTO. None of them ever appears in a response.
//
// Expected schema (adjust the queries below if yours differs):
//   profiles(id uuid = auth.users.id, photo_path text)  -- object key in PHOTO_BUCKET
//   verifications(session_id text primary key, user_id uuid, kind text, status text,
//                 created_at timestamptz default now(), decided_at timestamptz)

import { encodeBase64 } from 'jsr:@std/encoding@1.0.10/base64'
import { withSupabase } from 'npm:@supabase/server@1.9.2'

const DIDIT_SESSION_URL = 'https://verification.didit.me/v3/session/'
const PHOTO_BUCKET = 'profile-photos'
// Didit's limit for portrait_image.
const MAX_PORTRAIT_BYTES = 2 * 1024 * 1024

const WORKFLOW_SECRETS = {
  id: 'DIDIT_WORKFLOW_ID_IDCHECK',
  photo: 'DIDIT_WORKFLOW_ID_PHOTO',
} as const
type Kind = keyof typeof WORKFLOW_SECRETS

const json = (body: unknown, status = 200) => Response.json(body, { status })

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

    let kind: unknown
    try {
      ;({ type: kind } = await req.json())
    } catch {
      return json({ error: 'invalid_body' }, 400)
    }
    if (kind !== 'id' && kind !== 'photo') return json({ error: 'invalid_type' }, 400)

    const apiKey = Deno.env.get('DIDIT_API_KEY')
    const workflowId = Deno.env.get(WORKFLOW_SECRETS[kind as Kind])
    if (!apiKey || !workflowId) {
      console.error(`DIDIT_API_KEY or ${WORKFLOW_SECRETS[kind as Kind]} is not set`)
      return json({ error: 'not_configured' }, 500)
    }

    // Confirm the session against Auth rather than trusting the JWT alone, so a
    // deleted or anonymous user can't start a verification.
    const { data: { user }, error: userError } = await ctx.supabase.auth.getUser()
    if (userError || !user || user.is_anonymous) return json({ error: 'not_signed_in' }, 401)

    // supabaseAdmin bypasses RLS, so every query is filtered to the caller.
    const db = ctx.supabaseAdmin

    const { data: profile, error: profileError } = await db
      .from('profiles')
      .select('photo_path')
      .eq('id', user.id)
      .maybeSingle()
    if (profileError) {
      console.error('profile lookup failed', profileError)
      return json({ error: 'lookup_failed' }, 500)
    }
    if (!profile) return json({ error: 'not_a_member' }, 403)

    const body: Record<string, unknown> = { workflow_id: workflowId, vendor_data: user.id }

    if (kind === 'photo') {
      if (!profile.photo_path) return json({ error: 'no_profile_photo' }, 400)
      const { data: photo, error: photoError } = await db.storage.from(PHOTO_BUCKET).download(profile.photo_path)
      if (photoError || !photo) {
        console.error('profile photo download failed', photoError)
        return json({ error: 'profile_photo_unavailable' }, 500)
      }
      if (photo.size > MAX_PORTRAIT_BYTES) return json({ error: 'profile_photo_too_large' }, 400)
      body.portrait_image = encodeBase64(new Uint8Array(await photo.arrayBuffer()))
    }

    const res = await fetch(DIDIT_SESSION_URL, {
      method: 'POST',
      headers: { 'x-api-key': apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    const session = await res.json().catch(() => null)
    if (!res.ok || !session?.session_id || !session?.url) {
      // Log Didit's message for debugging; the app only sees a generic error.
      console.error('Didit session create failed', res.status, session)
      return json({ error: 'verification_unavailable' }, 502)
    }

    // Record the session so the webhook knows which member and check it belongs to.
    const { error: insertError } = await db.from('verifications').insert({
      session_id: session.session_id,
      user_id: user.id,
      kind,
      status: session.status ?? 'Not Started',
    })
    if (insertError) {
      console.error('verification insert failed', insertError)
      return json({ error: 'verification_unavailable' }, 500)
    }

    return json({ url: session.url })
  }),
}
