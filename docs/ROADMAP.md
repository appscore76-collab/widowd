# Roadmap: the full widowd mobile and web app on dev

_Gap report from 1 November 2026. Items done since are marked **Done**._

## Context
This lists what is still missing to build the full app in the design canvas (24 screens, "Widowd iOS App") as an iOS app, an Android app and a full web version. The target is the **dev environment only** (`widowd-dev`, Cloudflare preview URLs), not production. The scope is **iOS + Android** and **full features on the web, adapted** (Stripe for paid plans on the web; screenshot blocking on mobile only).

Each layer was checked read-only: the repo, both Supabase projects, auth settings, Edge Functions, GitHub Actions, Cloudflare and the design files. This is the gap report, then a phased plan to close the gaps.

---

## 1. What exists and works today (verified)

| Layer | State |
|---|---|
| **Flutter app** (branch `claude/loving-faraday-sxtqui`) | Flutter 3.47.8, **web platform only**. Landing page, sign-in/up/reset, 4-step profile setup, Discover (system suggestions), Search (keyword + badge filters), member profile, My profile. 24 widget tests pass. Packages: `supabase_flutter`, `image_picker`, `video_player`, `url_launcher`. |
| **widowd-dev database** | `profiles`, `matches`, `verifications`, all with RLS. Private `profile-photos` bucket. `private.suggest_matches_for()` with a daily pg_cron job (`suggest-matches-daily`, active). 3 migrations in `supabase/migrations/`. |
| **widowd-dev auth** | Email/password works, with confirmation emails on (`mailer_autoconfirm: false`). Phone sign-in is switched on with Twilio, but the app doesn't use it. |
| **Edge Function code** | `create-video-call` (Daily), `start-verification` and `didit-webhook` (Didit) are in the repo. The npm package they import (`@supabase/server@1.9.2`) exists. |
| **CI/CD** | `deploy-web.yml` runs tests, builds and deploys to Cloudflare Pages; the last 11 runs succeeded, so the Cloudflare secrets are set. The preview `claude-loving-faraday-sxtqui.widowd.pages.dev` serves the latest build. |

## 2. Connection and infrastructure gaps (dev)

| # | Gap | Evidence | Fix |
|---|---|---|---|
| C1 | ~~No Edge Functions deployed~~ **Done** | All three deployed to widowd-dev | They answer `not_configured` until C2's secrets are set. |
| C2 | Daily and Didit secrets: can't tell from here whether they're set | Can't be listed from this session | Set `DAILY_API_KEY`, `DAILY_DOMAIN`, `DIDIT_API_KEY`, `DIDIT_WORKFLOW_ID_IDCHECK`, `DIDIT_WORKFLOW_ID_PHOTO` and `DIDIT_WEBHOOK_SECRET` on widowd-dev. Point the Didit webhook at the dev function URL. |
| C3 | **Google and Apple sign-in not enabled** | `/auth/v1/settings`: only `email` and `phone` are true | Set up Google and Apple OAuth on widowd-dev. Mobile also needs native sign-in (`google_sign_in`, `sign_in_with_apple`) passing ID tokens to Supabase. |
| C4 | Auth email sender and redirect URLs | Built-in sender only reaches your Supabase team; redirect list unknown | Add custom SMTP (e.g. Resend or Postmark). Add `https://*.widowd.pages.dev/**`, `http://localhost:*/**` and the mobile deep link (`widowd://login-callback`) to the redirect URLs. |
| C5 | **No Android or iOS projects** in the repo | Only `web/` exists | Run `flutter create --platforms=ios,android .`. Pick bundle ID `app.widowd` (or yours); add a dev flavor pointing at widowd-dev. |
| C6 | **No mobile accounts, signing or builds** | — | Needs an Apple Developer account ($99/yr) with App Store Connect (TestFlight) and a Google Play Console account ($25) for internal testing. Signing keys go in GitHub secrets. CI: GitHub macOS runner + fastlane, or Codemagic. |
| C7 | ~~No Supabase CLI config or deploy pipeline~~ **Done** | `supabase/config.toml`, `deploy-supabase-dev.yml`, CLI in `cloud-setup.sh` | Add the `SUPABASE_ACCESS_TOKEN` and `SUPABASE_DEV_DB_PASSWORD` repository secrets to turn the workflow on. |
| C8 | ~~Push notifications~~ **Mostly done** | firebase_core + firebase_messaging; `firebase_options.dart`; web SW; Android gradle plugin; `device_tokens` table + RLS + RPCs on widowd-dev; permission request after sign-up; token saved/refreshed/removed. | Left: iOS APNs key + Push capability (needs Apple Developer, C6); the `send-push` Edge Function; mobile CI must provision the gitignored native config files. |
| C9 | Payments: none | `plus_expires_at` exists but nothing sets it | **RevenueCat**: App Store, Google Play and Stripe (web) all feed one webhook, and an Edge Function `billing-webhook` sets `plus_expires_at`. Needs store products and a Stripe test-mode account. |
| C10 | Maps and places: none | PlanDate/PickPlace show `[Map]` | Google Places API (search and nearby "busy public places") behind an Edge Function `places-search` so the key stays server-side. Maps with `google_maps_flutter` (works on web too). Store member location as PostGIS `geography`. |
| C11 | SMS to trusted contacts (Share my date) | Twilio already appears enabled for phone auth | Reuse Twilio from an Edge Function `share-date-alert`. Set Twilio secrets on dev. |
| C12 | Branching | PR appscore76-collab/widowd#1 open; this branch stacks on it; `main` (production) is still the starter app | Merge #1, then open a PR for this branch. Keep production untouched until you decide. |
| C13 | ~~Security advisor warning~~ **Done** | EXECUTE on `public.rls_auto_enable()` revoked from the API roles | — |
| C14 | ~~No error monitoring~~ **Done in code** | `sentry_flutter` added; on when built with `SENTRY_DSN` | Add the `SENTRY_DSN` repository variable. |

`widowd-staging` is empty. It isn't needed for a dev-only target; leave it alone.

## 3. Feature gaps by design screen

Legend: ✅ built · 🟡 partly · ❌ missing. **DB** = new tables/functions needed.

| Design screen | State | What's missing (app + backend) |
|---|---|---|
| 01 Welcome | 🟡 | Native mobile version, Apple-first buttons on iOS |
| 02 Dating intent + journey | ❌ | DB: `profiles.intent`, `journey`. Onboarding step |
| 03 Family & children | ❌ | DB: `children_count`, `children_ages`, `children_at_home`, `open_to_children`. Onboarding step and shown on profile |
| 04 Photos (up to 6, blurred) | 🟡 single photo | DB: `profile_photos` table (6 slots, order, main). **Blurred copy generated at upload** (Edge Function `process-photo`). Storage policy serves full photos only to people the owner has unlocked for |
| 05 Discover (like / pass, blurred until like) | 🟡 suggestions only | DB: `likes`, `passes`; mutual like turns a match into `matched`; photo unlock per like; daily limit "3 of 10"; profile prompts (`ready_for`, `perfect_sunday`, interests[], occupation) |
| 06 Search (distance, age, verified-only Plus) | 🟡 keyword + badges | Location (PostGIS), distance and age filters, verified-only gated to Plus, children shown in results |
| 07 Profile after like | 🟡 | Photo carousel, "Active today" (`last_active_at`), occupation, stats from new fields, Message / Plan a date / report / block buttons |
| 08 Chats list | ❌ | DB: `conversations`, `messages` (Realtime), unread counts, filters (Unread / Dates / Blocked), search |
| 09 Chat + ⋯ menu | ❌ | Realtime messaging (Plus to send), read receipts, mute, report, block sheet |
| 10 Chat blocked | ❌ | DB: `blocks`. RLS hides blocked users everywhere and cancels dates |
| 11 View-once photos (multi-select ≤10) | ❌ | Private bucket `chat-photos`. Edge Function signs each URL once and marks it opened |
| 12–13 Plan a date / Choose a place | ❌ | DB: `date_invites`; Places search; halfway-point suggestions (PostGIS); video-date option |
| 14 Date invite received | ❌ | Accept / suggest new time / decline, calendar add (`add_2_calendar`), reminders via pg_cron + push |
| 15 Share my date (Plus) | ❌ | DB: `trusted_contacts`, `date_shares`, `location_pings`. Live location during the date only (`geolocator`, background on mobile), check-in timer, SMS alerts |
| 16 Video chat (Plus) | 🟡 function exists, not deployed | Flutter: Daily SDK on mobile (`daily_flutter`), Daily Prebuilt in an `HtmlElementView` on the web. Mute, camera and timer UI |
| 17 Paywall | ❌ | RevenueCat paywall (mobile), Stripe Checkout (web), restore purchases, entitlement checks in RLS and functions |
| 18 Photo verification | 🟡 functions exist | UI to start the Didit flow (in-app browser), status screen, badge refresh (Realtime on `profiles`) |
| 19 ID check | 🟡 functions exist | Same as 18, with the document picker |
| 20 Incognito & privacy | ❌ | DB: `privacy_settings` (incognito, hide age, hide distance, read receipts, paused, who can message). RLS must respect incognito ("only people you've liked") |
| 21–23 Community, discussion, new post | ❌ | DB: `community_aliases` (random nickname), `posts`, `replies`, `helpful`, `reports`. Trigger rejecting contact details (phone, email, URL, handles). Moderation queue |
| Cross-cutting: screenshot blocking | ❌ | Android `FLAG_SECURE`; iOS hide-on-capture via a plugin (e.g. `screen_protector`). Web shows a notice instead |
| Cross-cutting: reports & moderation | ❌ | DB: `reports` (profiles, messages, posts), plus a minimal admin view (Supabase dashboard or a protected page) |
| Cross-cutting: notifications settings, account deletion, data export | ❌ | Needed for store review; account deletion is mandatory on both stores |

## 4. Recommended stack additions

- **Flutter packages:** `go_router` (deep links and web URLs), `flutter_riverpod` (state), `cached_network_image`, `google_sign_in`, `sign_in_with_apple`, `firebase_messaging`, `purchases_flutter` (RevenueCat), `google_maps_flutter`, `geolocator`, `daily_flutter`, `screen_protector`, `add_2_calendar`, `sentry_flutter`
- **Backend (Supabase):** Postgres + PostGIS, Realtime (messages, badges, invites), Storage (3 buckets), pg_cron (suggestions, reminders, check-ins), and these Edge Functions: `process-photo`, `send-push`, `billing-webhook`, `places-search`, `share-date-alert`, `view-once-photo`, plus the three existing
- **Services (dev/test mode):** Daily, Didit, RevenueCat, Stripe (test mode), Firebase (FCM), Google Cloud (Places/Maps, OAuth), Apple Developer, Google Play Console, Twilio, an SMTP provider, Sentry

## 5. Phased plan (dev environment)

Each phase ends with tests, a Cloudflare preview, and mobile builds on TestFlight / Play internal testing from phase 2 onward.

1. **Foundations.** Mostly done:
   - **Done:** Supabase CLI, `config.toml` and the dev deploy workflow (C7); the 3 Edge Functions deployed (C1); the advisor warning fixed (C13); Sentry in code (C14); `go_router` (page URLs) and Riverpod (shared state) with the existing screens.
   - **Left:** merge appscore76-collab/widowd#1 (C12; this deploys production, so it's your call); set the function secrets (C2); SMTP and redirect URLs in the Supabase dashboard (C4); the GitHub secrets and variable for C7 and C14.
2. **Mobile shells.**
   - Add the iOS and Android projects with a dev flavor (C5).
   - Native Google and Apple sign-in with deep links (C3).
   - Signing and CI to TestFlight and Play internal testing (C6); FCM push setup (C8).
3. **Richer profiles and Discover.**
   - Intent, journey, family, prompts and interests; 6 photos with blurred copies (03–04).
   - Likes, passes, mutual match and per-like photo unlock (05, 07).
   - Location with distance and age search (06).
4. **Safety and privacy core.**
   - Blocks, reports, privacy settings with incognito-aware RLS (10, 20).
   - Screenshot blocking (mobile); account deletion.
5. **Plus and payments.**
   - RevenueCat (App Store and Play sandbox) and Stripe test mode, webhook to `plus_expires_at` (17).
   - Gate messaging, video, verified-only search, Share my date and incognito on Plus.
6. **Chat.**
   - Conversations and messages over Realtime, read receipts, mute, push on new message (08–09).
   - View-once photos (11).
7. **Dates and video.**
   - Places + maps, halfway suggestions, invites with accept / reschedule / decline, reminders (12–14).
   - Video calls on mobile and web (16).
   - Share my date: live location, check-ins, SMS alerts (15).
8. **Verification UI.** Didit photo and ID flows with badge refresh (18–19).
9. **Community.** Aliases, posts, replies, helpful, contact-detail filter, reports and moderation (21–23).

## 6. Decisions and accounts you'll need to provide
- Apple Developer and Google Play Console accounts; the bundle ID / package name
- Test-mode keys: Daily, Didit, RevenueCat, Stripe, Google Cloud (Places/Maps + OAuth client IDs), Firebase, Twilio, SMTP
- Plus pricing (the landing page still shows `[PRICE]`), and who moderates reports and community posts

## 7. Verification (per phase)
- `flutter analyze` and `flutter test` (widget tests per screen, with the fake-repository pattern from `test/members_test.dart`)
- RLS tests run as SQL in rolled-back transactions, with the result in the exception message (the pattern used for the schema), for every new table, including block, incognito and Plus gates
- `get_advisors` (security + performance) after each migration
- Edge Functions exercised against dev with test-mode keys and their logs checked (`get_logs`)
- Web: Cloudflare preview plus Playwright screenshots at phone and desktop widths
- Mobile: a TestFlight / Play internal build run on a device, end to end — sign in, profile, like, match, chat, date invite, video call, purchase (sandbox), verification (Didit test mode)

**Next:** finish the Phase 1 items that need your accounts, then Phase 2 (mobile shells).
