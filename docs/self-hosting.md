# Self-hosting CLIVORA Community

This guide takes you from an empty Supabase project to a running web app and a signed Android build. Every value below is yours: nothing in this repository points at a hosted CLIVORA project.

## 1. Database

### Local

```bash
supabase start
```

This starts Postgres, Auth, Storage and Realtime in Docker and applies every file in `supabase/migrations` in order. It prints an **API URL** and an **anon key**; you need both below.

To reset to a clean database at any time: `supabase db reset`.

### Hosted

Create a project at supabase.com, then from the repository root:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

## 2. Vault secrets

Two scheduled database jobs call your edge functions. They read the address and a shared secret from Supabase Vault, so set these once (SQL editor, as the `postgres` role):

```sql
select vault.create_secret('https://<your-project-ref>.supabase.co', 'project_url');
select vault.create_secret('https://your-web-domain.example', 'site_url');
select vault.create_secret('<a long random string>', 'invoice_reminders_cron_secret');
```

For local development use `http://host.docker.internal:54321` as `project_url` and `http://localhost:3000` as `site_url`.

## 3. Edge functions

```bash
supabase functions deploy send-clivora-email
supabase functions deploy send-invoice-reminders
supabase functions deploy send-push
```

Configure email with either Resend or SMTP, plus your deployment details:

```bash
# Option A: Resend
supabase secrets set RESEND_API_KEY=... RESEND_FROM="CLIVORA <billing@your-domain.example>"

# Option B: SMTP over TLS (port 465)
supabase secrets set SMTP_HOST=smtp.your-provider.example SMTP_PORT=465 \
  SMTP_USER=billing@your-domain.example SMTP_PASS=... SMTP_FROM="CLIVORA <billing@your-domain.example>"

# Both
supabase secrets set SITE_URL=https://your-web-domain.example SUPPORT_EMAIL=support@your-domain.example
supabase secrets set CRON_SECRET=<same value as the invoice_reminders_cron_secret vault secret>
```

`PLAY_STORE_URL` is optional and only used for links in emails. For push notifications, also set `FIREBASE_SERVICE_ACCOUNT_JSON` to the JSON of a Firebase service account with Cloud Messaging access.

Configure Auth emails (sign-up confirmation, password reset) in the Supabase dashboard under Authentication, SMTP Settings, and add `https://your-web-domain.example/auth/reset-password` to the allowed redirect URLs.

## 4. Web app

```bash
cd apps/web
cp .env.example .env.local
```

Fill in at least `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY`. The service role key is used only in server code; never expose it to the browser.

Deploy anywhere that runs Next.js:

- **Vercel or similar:** import `apps/web` as the project root and set the same environment variables.
- **A Node host:** `npm ci && npm run build && npm start`. `npm start` binds to `$PORT`. For Passenger-based hosts, point the startup file at `server.js`.

Before opening the site to users, replace the template pages at `src/app/privacy/page.tsx` and `src/app/terms/page.tsx` with your own policy and terms.

## 5. Android app

```bash
cd apps/mobile
cp env/local.example.json env/release.json
```

Set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `CLIVORA_WEB_URL` and `CLIVORA_SUPPORT_EMAIL` in `env/release.json` (this file is gitignored).

Before publishing your own build:

1. Change `applicationId` in `android/app/build.gradle.kts` to an id you own.
2. Create an upload key and `android/key.properties` (both gitignored) as described in the Flutter Android deployment guide.
3. Optional: push notifications. Create a Firebase project, register your application id, and place its `google-services.json` in `android/app/`. Without it the app builds and runs normally, just without push.
4. Replace the template legal text in `lib/core/constants/legal_content.dart` and `legal_documents.dart`.

```bash
flutter build appbundle --release --dart-define-from-file=env/release.json
```

## 6. Admins and moderation

The Community edition does not include the admin console. Some database policies still recognise admins (for example, for moderating Connect listings). Admin status comes from the `public.admin_allowlist` table, which is empty by default:

```sql
insert into public.admin_allowlist (email) values ('you@your-domain.example');
```

## Connect credits

Connect actions are recorded in a ledger, but every account is unlimited in the Community edition (migration `20261003_community_unlimited_connect.sql`). Eligibility checks still apply: a confirmed email and a sufficiently complete profile.
