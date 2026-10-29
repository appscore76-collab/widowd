// Receives Didit verification webhooks, checks they're genuinely from Didit,
// records the approved/declined result and sets the member's badge.
//
// Didit doesn't send a Supabase JWT, so deploy with JWT verification off:
//   supabase functions deploy didit-webhook --no-verify-jwt
// The HMAC check below is what authenticates each request.
//
// Secret (supabase secrets set ...): DIDIT_WEBHOOK_SECRET, the destination's
// shared secret from the Didit console.
//
// Expected schema (adjust the queries below if yours differs):
//   verifications(session_id text primary key, user_id uuid, kind text, status text,
//                 created_at timestamptz default now(), decided_at timestamptz)
//   profiles(id uuid, id_verified boolean, photo_verified boolean)

import { decodeHex } from 'jsr:@std/encoding@1.0.10/hex'
import { withSupabase } from 'npm:@supabase/server@1.9.2'

// Didit asks receivers to reject webhooks more than 5 minutes old or early.
const MAX_CLOCK_SKEW_SECONDS = 300

const BADGE_COLUMNS: Record<string, string> = { id: 'id_verified', photo: 'photo_verified' }

const json = (body: unknown, status = 200) => Response.json(body, { status })

// Didit's X-Signature-V2 covers the body re-serialised with keys sorted at
// every level and no whitespace, so it survives any re-encoding in transit.
const canonicalJson = (value: unknown): string => JSON.stringify(sortKeys(value))
const sortKeys = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(sortKeys)
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value as Record<string, unknown>)
        .sort()
        .map((k) => [k, sortKeys((value as Record<string, unknown>)[k])]),
    )
  }
  return value
}

// crypto.subtle.verify compares in constant time.
const hmacMatches = async (key: CryptoKey, signatureHex: string | null, message: string) => {
  if (!signatureHex || !/^[0-9a-f]{64}$/i.test(signatureHex)) return false
  return await crypto.subtle.verify('HMAC', key, decodeHex(signatureHex), new TextEncoder().encode(message))
}

export default {
  fetch: withSupabase({ auth: 'none' }, async (req, ctx) => {
    if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

    const secret = Deno.env.get('DIDIT_WEBHOOK_SECRET')
    if (!secret) {
      console.error('DIDIT_WEBHOOK_SECRET is not set')
      return json({ error: 'not_configured' }, 500)
    }

    const timestamp = Number(req.headers.get('x-timestamp'))
    if (!Number.isFinite(timestamp) || Math.abs(Date.now() / 1000 - timestamp) > MAX_CLOCK_SKEW_SECONDS) {
      return json({ error: 'stale_or_missing_timestamp' }, 401)
    }

    const rawBody = await req.text()
    let event: Record<string, unknown>
    try {
      event = JSON.parse(rawBody)
    } catch {
      return json({ error: 'invalid_body' }, 400)
    }

    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify'],
    )
    // V2 first; the raw-body X-Signature is Didit's documented fallback. The
    // -Previous headers carry the old secret's signatures for 24h after a rotation.
    const canonical = canonicalJson(event)
    const authentic =
      (await hmacMatches(key, req.headers.get('x-signature-v2'), canonical)) ||
      (await hmacMatches(key, req.headers.get('x-signature-v2-previous'), canonical)) ||
      (await hmacMatches(key, req.headers.get('x-signature'), rawBody)) ||
      (await hmacMatches(key, req.headers.get('x-signature-previous'), rawBody))
    if (!authentic) return json({ error: 'invalid_signature' }, 401)

    // Anything other than a final decision is acknowledged so Didit doesn't retry it.
    const status = event.status
    if (event.webhook_type !== 'status.updated' || (status !== 'Approved' && status !== 'Declined')) {
      return json({ ok: true, ignored: true })
    }

    const sessionId = event.session_id
    if (typeof sessionId !== 'string') return json({ error: 'invalid_body' }, 400)

    const db = ctx.supabaseAdmin

    const { data: verification, error: lookupError } = await db
      .from('verifications')
      .select('user_id, kind')
      .eq('session_id', sessionId)
      .maybeSingle()
    if (lookupError) {
      console.error('verification lookup failed', lookupError)
      return json({ error: 'lookup_failed' }, 500)
    }
    // Only sessions start-verification created, for the member they were created for.
    if (!verification || verification.user_id !== event.vendor_data) {
      console.warn('webhook for unknown session', sessionId)
      return json({ ok: true, ignored: true })
    }
    const badgeColumn = BADGE_COLUMNS[verification.kind]
    if (!badgeColumn) {
      console.error('verification has unknown kind', sessionId, verification.kind)
      return json({ ok: true, ignored: true })
    }

    // A manual review can overturn an earlier decision, so the newest event wins
    // and an older one arriving late is skipped.
    const decidedAt = new Date(timestamp * 1000).toISOString()
    const { data: updated, error: updateError } = await db
      .from('verifications')
      .update({ status, decided_at: decidedAt })
      .eq('session_id', sessionId)
      .or(`decided_at.is.null,decided_at.lt.${decidedAt}`)
      .select('session_id')
    if (updateError) {
      console.error('verification update failed', updateError)
      return json({ error: 'update_failed' }, 500)
    }
    if (!updated?.length) return json({ ok: true, ignored: true })

    const { error: badgeError } = await db
      .from('profiles')
      .update({ [badgeColumn]: status === 'Approved' })
      .eq('id', verification.user_id)
    if (badgeError) {
      console.error('badge update failed', badgeError)
      return json({ error: 'update_failed' }, 500)
    }

    return json({ ok: true })
  }),
}
