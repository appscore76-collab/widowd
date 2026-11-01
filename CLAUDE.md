# CLAUDE.md — widowd project rules

widowd is a dating app for widows and widowers, built with **Flutter** for
**iOS, Android and web** from one codebase (`lib/`). The backend is
**Supabase** (Postgres + RLS, Auth, Storage, Edge Functions). The web app
deploys to Cloudflare Pages.

See `docs/SETUP.md` for how the pieces connect and `docs/ROADMAP.md` for
what's built and what's next.

## 1. Supabase: dev only

- Use the **`widowd-dev`** project only (ref `gzgrbbeohcerznezawna`).
- **Never** touch `widowd-staging` (`dhpjlwicmtszknhefwfr`) or any
  production project — no migrations, function deploys, SQL writes or
  secret changes against them.
- Schema changes are SQL migrations in `supabase/migrations/`, applied to
  `widowd-dev`. Edge Functions live in `supabase/functions/`. Both reach
  `widowd-dev` through `.github/workflows/deploy-supabase-dev.yml`.
- The app defaults to `widowd-dev`; point a build elsewhere only with
  `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`.

## 2. No secrets in code

- Never commit API keys, tokens, passwords, private keys or signing files.
  `.gitignore` excludes `.env*`, `*.pem/key/p8/p12/jks/keystore`,
  `key.properties`, `google-services.json`, `GoogleService-Info.plist`,
  service-account JSON and similar — keep it that way.
- The only credential that may ship in the app is the Supabase
  **publishable (anon) key**; RLS is what protects data, not the key.
- Server-side secrets (Daily, Didit, Twilio, SMTP, …) are set with
  `supabase secrets set` on `widowd-dev` and read only by Edge Functions.
- CI secrets (Cloudflare, Supabase access token and DB password) live in
  **GitHub repository secrets**; the Sentry DSN is a repository variable.
- Build-time values come from `--dart-define` (see `lib/main.dart`), never
  hard-coded.

## 3. Security rules (from the plan doc)

- **RLS on every table**, always. A new table is not done until its
  policies and privileges are written and tested.
- Members may read listed profiles and their own, and may **update only
  their own editable columns** (`display_name`, `birth_year`, `gender`,
  `interested_in`, `city`, `bio`, `photo_path`).
- `plus_expires_at`, `id_verified` and `photo_verified` are written
  **server-side only** (service role / Edge Functions). Members cannot read
  `plus_expires_at`. Matches, likes and badges are written server-side too.
- Anonymous sessions see nothing. Blocked and incognito users must be
  hidden by RLS everywhere they would otherwise appear.
- Storage: members upload only into their own `<user-id>/` folder; others'
  photos are served through short-lived signed URLs, never public buckets.
- Edge Functions: keep `verify_jwt = true` except `didit-webhook`, which is
  `false` because Didit sends no Supabase token and the function verifies
  Didit's HMAC signature itself (set in `supabase/config.toml`).
- `SECURITY DEFINER` functions stay in the `private` schema (or have
  EXECUTE revoked from `anon`/`authenticated`) and set `search_path`.

## 4. Testing and quality gates

- Before every commit: `flutter analyze` (zero issues) and `flutter test`.
- Widget tests use the fake-repository pattern in `test/members_test.dart`;
  the real Plus Jakarta Sans font is loaded via `test/test_fonts.dart` so
  layout is measured correctly, and layouts are checked for overflow at
  phone and desktop widths.
- For any new table or policy, write an **RLS test**: SQL run inside a
  rolled-back transaction, asserting what each role can and cannot do, with
  the result surfaced in the transaction's exception message.
- Run `get_advisors` (security and performance) after each migration and
  resolve what it flags.

## 5. Git and deploys

- Develop on a feature branch; do not commit directly to `main`. Open a
  pull request for review.
- `main` is the production branch: a push to it deploys the web app to
  Cloudflare production via `.github/workflows/deploy-web.yml`. Merge with
  that in mind.
- Run `flutter analyze` and `flutter test` green before pushing.
