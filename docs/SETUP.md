# Setup guide

How the widowd repository, its deployments and its Claude Code on the web
environment fit together, and how to set each one up.

## What's in the repo

| Path | What it is |
| --- | --- |
| `lib/`, `test/`, `web/`, `pubspec.yaml` | The Flutter app (web only for now): landing page, sign-in, and the free member features (profile, browse, match suggestions) |
| `supabase/migrations/` | Database schema, row-level security, the `profile-photos` bucket and the daily match-suggestion job |
| `.github/workflows/deploy-web.yml` | Builds the web app and deploys it to Cloudflare Pages |
| `supabase/functions/create-video-call/` | Edge Function: Daily video call token for two matched Plus members |
| `supabase/functions/start-verification/` | Edge Function: starts a Didit ID or photo verification |
| `supabase/functions/didit-webhook/` | Edge Function: receives Didit results and sets badges |
| `scripts/cloud-setup.sh` | Setup script for the Claude Code on the web environment |

## 1. GitHub

The repository is `appscore76-collab/widowd`, with `main` as the default and
production branch.

**Give Claude access** so Claude Code on the web can clone and push:

1. Go to https://claude.ai/connect-github and connect your GitHub account.
2. Install the Claude GitHub App when asked. Choose the `appscore76-collab`
   account, then **Only select repositories** and pick `widowd`.

If `appscore76-collab` is an organization you don't own, an owner has to
approve the install.

**Add the Actions secrets** under the repository's
**Settings > Secrets and variables > Actions**:

| Secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | A Cloudflare API token with the **Cloudflare Pages: Edit** permission |
| `CLOUDFLARE_ACCOUNT_ID` | Your Cloudflare account ID |

## 2. Cloudflare Pages

The deploy workflow uploads `build/web` to a Pages project. It doesn't create
the project.

1. In Cloudflare, create a Pages project named `widowd` using **Direct Upload**.
2. Set its production branch to `main`.

After that:

- **Pushes to `main`** deploy to production at https://widowd.pages.dev.
- **Pull requests** from branches in this repository get a preview deployment,
  and the workflow comments the preview URL on the pull request. Pull requests
  from forks are skipped because they can't read the secrets.

## 3. Claude Code on the web

Open the cloud environment menu in a session's title bar and choose **Edit**
to change these settings. New sessions pick up the changes.

**Repository.** Select `appscore76-collab/widowd` when starting a session.

**Setup script.** Paste the contents of [`scripts/cloud-setup.sh`](../scripts/cloud-setup.sh)
into **Setup script**. It installs Flutter 3.47.8 if the image doesn't
already have it, downloads the web build tools and runs `flutter pub get`.
The script can't read the environment's variables or secrets.

**Environment variables.** Add:

| Variable | Value | Why |
| --- | --- | --- |
| `CHROME_EXECUTABLE` | `/opt/pw-browsers/chromium` | Lets `flutter run -d chrome` and `flutter test --platform chrome` use the Chromium that's already in the container |

**Network access.** Flutter needs to reach GitHub (`github.com`), Google's
Flutter downloads (`storage.googleapis.com`) and pub (`pub.dev`). If the setup
script fails with a denied host, add that host under **Allowed domains** and
keep **Allow package managers** ticked. Details:
https://code.claude.com/docs/en/cloud-environments#network-access

**Connectors.** Connect the Supabase connector in your claude.ai connector
settings so Claude can read the Supabase projects. It needs access to the
organization that holds `widowd-dev` and `widowd-staging`.

## 4. Flutter

The project uses Flutter **3.47.8** on the stable channel (Dart 3.13.7). The
deploy workflow uses the latest stable release.

```bash
flutter pub get
```

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter build web --release
```

```bash
flutter run -d chrome
```

Only the web platform is set up. `flutter doctor` will report the Android
toolchain and Linux desktop libraries as missing in the cloud container; neither
is needed for web work.

## 5. Supabase

| Project | Ref |
| --- | --- |
| `widowd-dev` | `gzgrbbeohcerznezawna` |
| `widowd-staging` | `dhpjlwicmtszknhefwfr` |

**Database schema.** `supabase/migrations/` holds the schema. It has been
applied to `widowd-dev`; apply it to `widowd-staging` (and any new project)
with:

```bash
supabase link --project-ref dhpjlwicmtszknhefwfr
```

```bash
supabase db push
```

What it creates:

- `profiles`: one row per account, created automatically at sign-up. Members
  can read listed profiles and their own, and can update only their own
  `display_name`, `birth_year`, `gender`, `interested_in`, `city`, `bio` and
  `photo_path`. `plus_expires_at`, `id_verified` and `photo_verified` are set
  only by Edge Functions (service role), and members can't read
  `plus_expires_at`. A profile is `listed`, and shown to others, once it has
  a name, birth year, gender, who they're interested in and a photo.
- `matches`: one row per pair (`user_a < user_b`). The system writes
  suggestions with status `'suggested'`; `'matched'` is what
  `create-video-call` treats as active. Members can only read their own rows.
- `verifications`: written by `start-verification` and `didit-webhook`;
  members can read their own.
- The private `profile-photos` bucket (2 MB, JPEG/PNG/WebP). Members upload
  into a folder named after their user ID; photos of listed members are
  readable by signed-in members through signed URLs.
- **Match suggestions.** When a profile becomes listed, it gets up to 3
  suggestions straight away, and a `pg_cron` job (`suggest-matches-daily`,
  04:17 UTC) tops up every listed member by 3 more each day. People are
  suggested when each is interested in the other's gender and they're within
  15 years of age; closer age, the same town and verification badges rank
  higher. The logic is in `private.suggest_matches_for()`.

**Secrets.** Set these per project. They're read only by the Edge Functions
and never returned to the app.

```bash
supabase secrets set DAILY_API_KEY=... DAILY_DOMAIN=... --project-ref gzgrbbeohcerznezawna
```

```bash
supabase secrets set DIDIT_API_KEY=... DIDIT_WORKFLOW_ID_IDCHECK=... DIDIT_WORKFLOW_ID_PHOTO=... DIDIT_WEBHOOK_SECRET=... --project-ref gzgrbbeohcerznezawna
```

**Deploy the functions.** `didit-webhook` needs JWT verification off because
Didit doesn't send a Supabase token; it checks Didit's signature instead.

```bash
supabase functions deploy create-video-call --project-ref gzgrbbeohcerznezawna
```

```bash
supabase functions deploy start-verification --project-ref gzgrbbeohcerznezawna
```

```bash
supabase functions deploy didit-webhook --no-verify-jwt --project-ref gzgrbbeohcerznezawna
```

**Third-party settings:**

- **Daily:** make sure recording isn't turned on as a default for the whole
  domain.
- **Didit:** set the webhook URL to
  `https://gzgrbbeohcerznezawna.supabase.co/functions/v1/didit-webhook`.

**Sign-in.** The app offers email and password, Google and Apple. It connects
to `widowd-dev` by default; build against staging with
`--dart-define=SUPABASE_URL=https://dhpjlwicmtszknhefwfr.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=...`.
In each project, under **Authentication**:

- **URL Configuration:** set the Site URL to `https://widowd.pages.dev` and
  add `https://widowd.pages.dev/**`, `https://*.widowd.pages.dev/**` (preview
  deploys) and `http://localhost:*/**` to the redirect URLs. Google, Apple,
  confirmation emails and password-reset emails all send members back here.
- **Sign In / Providers → Email:** on by default. Keep "Confirm email" on.
- **Sign In / Providers → Google:** create an OAuth client ID (type "Web
  application") in Google Cloud Console, add
  `https://<project-ref>.supabase.co/auth/v1/callback` as an authorized
  redirect URI, then paste the client ID and secret into Supabase.
- **Sign In / Providers → Apple:** needs a paid Apple Developer account. Create
  a Services ID with Sign in with Apple, set its return URL to the same
  callback, create a Sign in with Apple key, and enter the Services ID, team
  ID, key ID and key in Supabase. Apple's secret expires every 6 months.
- **Emails:** Supabase's built-in email sender is rate-limited and meant for
  testing; set up custom SMTP before launch.

## Troubleshooting

- **Setup script fails with `Could not find a command named "--version#!/bin/bash"`.**
  Two lines ran together in the pasted script. Replace the whole script with
  `scripts/cloud-setup.sh`.
- **"Woah! You appear to be trying to run flutter as root."** Only a warning;
  the cloud container runs as root.
- **A push from Claude is refused with "Claude doesn't have GitHub access".**
  Redo step 1, then start a new session.
- **The deploy workflow fails at `wrangler`.** Check that the Pages project
  exists with the exact name `widowd` and that the API token has
  **Cloudflare Pages: Edit**.
