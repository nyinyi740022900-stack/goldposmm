# GoldPOSMM — project guide for Claude

Offline-first POS + license SaaS for Myanmar SMEs. **Flutter** app (iOS/Android)
+ **Flutter Web** admin console + **Supabase** (Postgres/Auth/Edge Functions).
Two languages everywhere: English + Myanmar.

## Stack & conventions
- **State:** Riverpod. **Routing:** go_router (`StatefulShellRoute`, 6 tabs:
  Sell, Inventory, Orders, Invoices, Analytics, Settings).
- **Local DB:** Drift (SQLite) — offline source of truth. **Cloud:** Supabase.
- **Structure:** feature-first under `lib/features/<name>/` (screen + providers +
  repository). Shared: `lib/core`, `lib/data` (local db, repositories, sync),
  `lib/domain`. Admin web is a separate entry point: `lib/admin/` (built with
  `-t lib/admin/admin_main.dart`, tree-shaken out of the mobile app).
- **Money** is `int` kyat (no cents). Use the `Money` value object.
- **Pure logic** (analytics, credit aggregation, license status, receipt
  formatting) lives in plain Dart classes with unit tests — keep it that way.

## ⚠️ Adding a synced table (do ALL of these — easy to miss a step)
1. `lib/data/local/tables.dart` — new table `with SyncColumns`.
2. `lib/data/local/database.dart` — register in `@DriftDatabase`, bump
   `schemaVersion`, add an `onUpgrade` `addColumn`/`createTable` branch.
3. `dart run build_runner build` (regenerates `database.g.dart`).
4. `lib/data/sync/sync_mappers.dart` — add a `SyncTableDef` (toRemote +
   upsertLocal with last-write-wins) and register it in `syncTables`.
5. `supabase/migrations/00NN_*.sql` — create the table **with RLS**:
   `enable row level security` + a `shop_isolation` policy
   (`shop_id = auth_shop_id()`). NOT dev-open. (See the 0012 lesson below.)
6. If it holds a counter (like stock): sync **movement deltas append-only**,
   never absolute quantities with LWW (LWW loses concurrent updates).

## Sync model (don't break these invariants)
- **Outbox pattern:** every mutation writes local + enqueues to `outbox`; the
  sync engine drains it. The push loop **isolates failures** — one bad row must
  not wedge the queue (regression-tested in `sync_engine_test.dart`).
- **Sales are append-only** (immutable ledger) — never update a sale.
- Every row has a client-generated UUID (idempotent retries).
- **Multi-tenant:** RLS `shop_isolation` on every synced table; users get the
  `shop_id` JWT claim via `activate` (keys) or `start_trial` (trials). Applying
  a migration that only drops `dev_open` without (re)creating `shop_isolation`
  will make tables default-deny and break the app — always recreate it.

## i18n (parity is enforced by a test)
- Add every string to BOTH `lib/l10n/app_en.arb` AND `lib/l10n/app_my.arb`,
  then `flutter gen-l10n`. `i18n_parity_test.dart` fails on missing keys.

## Licensing
- Online: key `activate` (device-bound, one device per key) + subscribe
  requests + auto re-verify. Offline: **Ed25519 signed tokens** (`MMPOS1.`
  prefix) verified locally against the public key in `offline_license.dart`
  (private key is a Supabase secret, NEVER in the repo). Free 2-month trial is
  server-tracked per device.

## Security — hard rules
- **NEVER commit** `env.local.json`, private keys (hex seeds), or the Supabase
  service-role key. Anon key is fine (RLS enforces access).
- New tables/functions must enforce shop isolation / admin-role checks.
- Edge Functions hold the service role; the client only ever has the anon key.

## Workflow
- Before any build: `flutter analyze` (clean) + `flutter test` (all pass).
- **Reflect every change in `PROJECT_SPEC.md` §12 changelog** (same change-set).
- Deploy: see the `deploy` skill (db push → functions deploy → admin web to
  Vercel → build to device). Test migrations on staging before prod.
- Build to the phone: `flutter run --release -d <ios-device> --dart-define-from-file=env.local.json`.
