# Contributing to CLIVORA

Thank you for helping build a fair, useful Freelancer OS.

## Before you start

- Search existing issues and discussions before opening a new one.
- For anything larger than a small fix, open an issue first so the approach can be agreed before you write code.
- Read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [GOVERNANCE.md](GOVERNANCE.md).

## Repository layout

| Path | What it is |
|---|---|
| `apps/web` | Next.js web app (App Router, TypeScript, Tailwind) |
| `apps/mobile` | Flutter app for Android (offline-first, Drift SQLite, Riverpod) |
| `supabase/migrations` | Postgres schema, row-level security policies and database functions |
| `supabase/functions` | Supabase Edge Functions (email, push, invoice reminders) |
| `docs` | Architecture and self-hosting guides |

## Local development

You need Node.js 20 or 22, the Flutter SDK (stable), Docker, and the [Supabase CLI](https://supabase.com/docs/guides/cli).

```bash
# 1. Backend: start Postgres, Auth, Storage locally and apply every migration
supabase start

# 2. Web
cd apps/web
cp .env.example .env.local     # paste the API URL and anon key printed by `supabase start`
npm ci
npm run dev                    # http://localhost:3000

# 3. Mobile
cd ../mobile
cp env/local.example.json env/local.json   # same values; 10.0.2.2 reaches your machine from the Android emulator
flutter pub get
flutter run --dart-define-from-file=env/local.json
```

Full details, including email and push notifications, are in [docs/self-hosting.md](docs/self-hosting.md).

## Before you open a pull request

Run the same checks CI runs:

```bash
cd apps/web && npm run typecheck && npm run lint && npm test && npm run build
cd apps/mobile && flutter analyze && flutter test
```

- Keep changes focused. One concern per pull request.
- Add or update tests for behaviour changes.
- Database changes go in a new, timestamped file in `supabase/migrations`. Never edit a migration that has already been released.
- Every table needs row-level security and explicit policies. Pull requests that add a table without them will not be merged.
- Never commit credentials, signing keys, `.env` files, `google-services.json` or customer data.

## Developer Certificate of Origin

Contributions are accepted under the project licence (AGPL-3.0). Sign off each commit:

```bash
git commit -s -m "fix(invoices): round tax per line before summing"
```

By adding `Signed-off-by: Your Name <your@email>` to a commit, you certify that you have the right to submit the contribution under this repository's licence, as described at https://developercertificate.org.

## Good first areas

Accessibility, translations, test coverage, offline sync edge cases, documentation, and self-hosting improvements. Issues labelled `good first issue` are a good place to start.
