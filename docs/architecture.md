# Architecture

CLIVORA is two clients over one Supabase backend. All business data lives in Postgres and is protected by row-level security; the clients never use elevated credentials.

## Components

| Component | Stack | Notes |
|---|---|---|
| Web app (`apps/web`) | Next.js 15 App Router, React 19, TypeScript, Tailwind | Server components read through the Supabase SSR client with the user's session. The service role key is used only in a few server routes (public invoice links, review tokens, job ingest). |
| Android app (`apps/mobile`) | Flutter, Riverpod, GoRouter, Drift (SQLite) | Offline-first: the local database is the source of truth for the UI, and changes sync in the background. |
| Database (`supabase/migrations`) | Postgres with row-level security on every table | Business rules that must not be bypassed (Connect eligibility, credit ledger, milestone transitions) are database functions, not client code. |
| Edge Functions (`supabase/functions`) | Deno | Transactional email, push notifications, invoice reminders. Triggered by the clients or by `pg_cron`. |

## How the Android app syncs

Every local change is written in the same SQLite transaction as an entry in a durable outbox (`sync_outbox_entries`). Each entry carries a client-generated UUID (`operation_id`) and the owning user, so the server can apply it exactly once even if the device retries after losing a response.

A drain loop sends due entries to Supabase. Each entry moves through `pending`, `processing`, `retrying`, `conflicted`, `permanently_failed` or `completed`. Transient failures back off exponentially; entries whose kind is unrecognised are quarantined immediately so one bad entry cannot block the rest.

When the local and cloud versions of a record disagree and the device still has an unsent change for it, the conflict is staged for review instead of resolved by last-write-wins. The user picks **take cloud**, which overwrites the local copy, or **keep local**, which re-queues the local version as a new outbox entry so it passes through the same validation and row-level security as any other change.

Realtime events on a per-user channel tell the app to reconcile, debounced by 500 ms so a multi-table change triggers one pass.

## Editions

The Community edition contains no admin console, billing, ERP or campaign integrations, or AI features. Where a link to one of those could still be reached (for example an old deep link), the app shows an edition screen instead of an error. Plan checks always pass in Community: there are no paid tiers or limits.
