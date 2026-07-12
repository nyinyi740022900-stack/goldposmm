# PROJECT_SPEC.md — Myanmar Retail POS

> **Status:** Living document. Every implementation change MUST be reflected here in the same change-set.
> **Last updated:** 2026-07-10
> **Owner workstreams:** Frontend/UX · Backend/Security · QA/Spec

---

## 1. Product Overview

An **offline-first Point-of-Sale (POS) application for Myanmar retailers** (grocery, minimarts, pharmacies, phone/accessory shops, teashops). It runs on Android and iOS phones/tablets, works fully without internet, and syncs to the cloud when a connection is available.

### 1.1 Core value

- **Works with no internet.** All core operations (sell, add stock, print receipt) function offline. Sync is opportunistic.
- **Cheap hardware friendly.** Targets low-end Android devices and Bluetooth thermal mini-printers (58mm/80mm ESC/POS) common in Myanmar.
- **Myanmar-first UX.** Full Burmese (my) + English (en) localization, Myanmar Kyat (MMK) currency, local date formats, and payment methods (KBZPay, WavePay, AYAPay, CBPay, cash).
- **Subscription licensed.** Online license activation with offline grace period; supports local payment collection.

### 1.2 Non-goals (v1)

- No multi-branch consolidated accounting (single shop per license in v1; multi-device same-shop sync is in scope).
- No full ERP / payroll / supplier procurement automation.
- No web storefront / e-commerce.

---

## 2. Target Users & Devices

| Persona | Needs |
|---|---|
| Shop owner | Daily/period sales analytics, stock value, license & staff management |
| Cashier | Fast sell screen, barcode/qty entry, receipt printing, cash/mobile payment |
| Stock keeper | Add/adjust inventory, low-stock alerts, purchase entry |

- **OS:** Android 8+ (primary), iOS 14+ (secondary).
- **Form factor:** Phone (portrait) and tablet (landscape). Responsive layout required.
- **Printer:** Bluetooth ESC/POS thermal, 58mm & 80mm paper.

---

## 3. Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| App framework | **Flutter 3.44 / Dart 3.12** | Single codebase, Android + iOS |
| State mgmt | **Riverpod** | Testable, compile-safe DI |
| Routing | **go_router** | Declarative, deep-link ready |
| Local DB | **Drift (SQLite)** | Typed, reactive, migration support — source of truth on device |
| Backend | **Supabase** | Postgres + Row Level Security + Auth + Edge Functions |
| Sync | Custom pull/push over Supabase REST + a local outbox queue | Last-write-wins + updated_at, tombstones for deletes |
| Printing | `esc_pos_utils_plus` + `print_bluetooth_thermal` | ESC/POS byte generation + BT transport |
| i18n | Flutter `gen_l10n` (ARB files) | `en`, `my` |
| Analytics/charts | `fl_chart` | Sales dashboards |
| Auth/License | Supabase Auth + `licenses` table + Edge Function `activate` | Device-bound key, JWT claims |

---

## 4. Architecture

### 4.1 Offline-first principle

```
                 ┌─────────────────────────── Device (source of truth) ──────────────────────────┐
   UI (Flutter)  →  Riverpod controllers  →  Repositories  →  Drift (SQLite)  →  Outbox table
                                                                     │                  │
                                                                     │ (read models)    │ (queued mutations)
                                                                     ▼                  ▼
                                                              Reactive streams     SyncEngine
                                                                                        │  (when online + licensed)
                                                                                        ▼
                                                                                   Supabase (Postgres/RLS)
```

- The **UI never talks to the network directly.** It reads/writes Drift. Repositories enqueue changes to an **outbox**; the `SyncEngine` drains the outbox and pulls remote changes on a schedule / connectivity change.
- **Conflict policy (v1):** last-write-wins by `updated_at` (server clock authoritative on push ack). Money-critical rows (sales) are **append-only** and never updated after finalization to avoid conflicts; corrections are separate reversal records.

### 4.2 Layered structure

```
lib/
  core/            # theme, constants, errors, utils, result types
  l10n/            # generated localizations
  data/
    local/         # Drift database, DAOs, tables
    remote/        # Supabase client, DTOs, mappers
    sync/          # SyncEngine, outbox, connectivity
    repositories/  # one repo per domain, offline-first
  domain/          # entities, value objects (Money, Barcode), use-cases
  features/
    auth/          # license activation + staff PIN login
    inventory/     # products, categories, stock
    sales/         # sell screen, cart, checkout
    invoices/      # receipt model + printing
    analytics/     # dashboards
    settings/      # shop profile, printer, language, license status
  app.dart         # router, theme, providers root
  main.dart
```

### 4.3 Money & rounding

- Store money as **integer minor units? No** — MMK has no widely used minor unit; store as integer **kyat** (`int`). A `Money` value object wraps `int amountKyat`. All arithmetic in integers to avoid float drift. Display with thousands separators.

---

## 5. Data Model (v1)

All tables carry: `id` (uuid), `shop_id` (uuid), `created_at`, `updated_at`, `is_deleted` (bool, tombstone), `dirty` (local-only sync flag).

- **shops** — id, name, address, phone, currency='MMK', logo, receipt_footer.
- **staff** — id, shop_id, name, pin_hash, role (owner/cashier/stock), active.
- **categories** — id, shop_id, name, sort.
- **products** — id, shop_id, name, sku, barcode, category_id, cost_price, sale_price, unit, image, is_active.
- **stock_levels** — product_id, quantity (int), reorder_level. (Denormalized current qty; movements are the ledger.)
- **stock_movements** — id, product_id, type (purchase/sale/adjustment/return), qty_delta, unit_cost, ref_id, note.
- **sales** — id, shop_id, invoice_no, staff_id, subtotal, discount, tax, total, paid, change, payment_method, customer_name?, note, finalized_at. **Append-only.**
- **sale_items** — id, sale_id, product_id, name_snapshot, price_snapshot, qty, line_total.
- **payments** — id, sale_id, method (cash/kbzpay/wavepay/ayapay/cbpay), amount, ref_no.
- **licenses** — id, shop_id, key, plan (monthly/yearly), status (active/expired/grace), activated_at, expires_at, device_id, last_verified_at.

**Supabase RLS:** every table scoped by `shop_id = auth.jwt() ->> 'shop_id'`. No cross-shop reads.

---

## 6. Licensing & Subscription

- **Model:** one license key → one shop, bound to a primary device_id at activation. Plans: monthly / yearly.
- **Activation flow:** enter key → Edge Function `activate(key, device_id)` validates + binds → returns signed license payload → stored locally.
- **Offline grace:** app works offline; license re-verified when online. If `expires_at` passed AND last successful verify > **7-day grace**, app enters **read-only** mode (can view, cannot finalize sales) until renewed.
- **Local payment support:** owner can record a renewal payment (KBZPay/Wave/cash) which flags the license for manual/automated reconciliation server-side. (Automated gateway integration is a later phase.)
- **Anti-abuse:** device binding, server-side expiry authoritative, key never trusted from client alone.

---

## 7. Bluetooth Receipt Printing

- ESC/POS command generation via `esc_pos_utils_plus`; transport via `print_bluetooth_thermal`.
- Support 58mm (32 char) and 80mm (48 char) profiles — configurable in settings.
- Receipt includes: shop name/logo, address/phone, invoice no, datetime, cashier, line items (name/qty/price/total), subtotal/discount/total, payment method + change, footer text, optional QR.
- **Burmese text on thermal printers** is a known hard problem (many printers lack Myanmar font). Strategy: render the receipt (or the Burmese portions) to a **bitmap image** and print as raster, so any Unicode renders correctly regardless of printer font support. English/numeric parts may use native text mode for speed.

---

## 8. Internationalization

- Languages: **en**, **my** (Burmese, Unicode — NOT Zawgyi). ARB files under `lib/l10n/`.
- All user-facing strings via generated `AppLocalizations`. No hardcoded strings in widgets.
- Numbers/currency: MMK formatting, optional Myanmar digit display toggle.
- QA workstream owns translation completeness + accuracy verification (see §11).

---

## 9. Security

- Supabase Auth (anonymous/device session bootstrapped by license activation).
- **RLS on every table.** Server never trusts client-supplied `shop_id`; derived from JWT.
- Staff PIN stored as salted hash (e.g. `bcrypt`/`argon2` via crypto lib) — never plaintext.
- Secrets (Supabase anon key is public by design; service key NEVER in app). Edge Functions hold privileged logic.
- Input validation on Edge Functions. Rate-limit `activate`.
- Local DB: consider SQLCipher for at-rest encryption (phase 3).

---

## 10. Delivery Phases

> Build order. Each phase ends in a runnable, demoable state. Spec updated per phase.

- **Phase 0 — Foundation (scaffold):** Flutter project, folders, theme, Riverpod, go_router, l10n (en/my), Drift DB skeleton, Supabase client config, CI-friendly analysis options. *Runnable empty-shell app.*
- **Phase 1 — Inventory:** categories + products CRUD, stock levels, low-stock alerts, barcode field, offline persistence. Seed/demo data.
- **Phase 2 — Sales / Sell screen:** cart, qty/discount, checkout, payment method, finalize sale (append-only), stock decrement, invoice number generation. Offline.
- **Phase 3 — Invoices & Bluetooth printing:** receipt model, ESC/POS generation, printer pairing/settings, Burmese raster fallback, reprint.
- **Phase 4 — Sync engine:** Supabase schema + RLS migrations, outbox drain, pull/merge, connectivity handling, conflict rules.
- **Phase 5 — Licensing:** licenses table, `activate` Edge Function, activation UI, grace/read-only enforcement, local renewal payment record.
- **Phase 6 — Analytics:** sales dashboards (daily/period), top products, profit (sale−cost), stock value, fl_chart visualizations.
- **Phase 7 — Hardening:** tests, security review, i18n QA pass, at-rest encryption, performance on low-end devices, release builds.

---

## 11. Workstreams (the three sub-agent roles)

### 11.1 Frontend / UX
- Responsive layouts (phone portrait + tablet landscape), Material 3 theme, Myanmar-appropriate typography (Pyidaungsu/Noto Sans Myanmar).
- Fast, low-friction sell screen; big tap targets; works one-handed.
- Consistency: shared widgets, spacing scale, theme tokens.

### 11.2 Backend / Security
- Supabase schema, RLS policies, Edge Functions (`activate`, sync helpers).
- Sync engine correctness, conflict handling, outbox reliability.
- License auth, device binding, vulnerability patching, secret hygiene.

### 11.3 QA / Spec
- Keep THIS file in sync with code every change.
- Translation accuracy (en/my) — no missing keys, correct Burmese.
- Functional + unit/widget tests; bug triage; release checklist.

---

## 13. Security Review (Phase 7)

Manual review of the current codebase. Status: no high-severity issues in app code.

**Good:**
- **No service-role key in the app.** Only the anon/publishable key ships (public
  by design). Privileged logic (device binding, `shop_id` claim) lives in the
  `activate` Edge Function, which alone uses `SUPABASE_SERVICE_ROLE_KEY`.
- **RLS on every synced table**, scoped by `auth_shop_id()` from the JWT. The
  server never trusts a client-supplied `shop_id`.
- **License authority is server-side** — expiry/binding validated in the Edge
  Function; the client cache is advisory only.
- **Money is integer kyat** — no floating-point rounding on financial values.
- Anon key kept out of source (`env.local.json` gitignored).

**Action items before production (tracked):**
1. **Remove dev-open policies** (`0002_dev_open_policies.sql`) and the demo
   license seed; rely solely on the `shop_id`-claim RLS from `0001`/`0003`.
2. **At-rest DB encryption** — swap `sqlite3_flutter_libs` for
   `sqlcipher_flutter_libs` + a keystore-backed passphrase (deferred; documented).
3. **Rate-limit `activate`** (per-IP / per-key) to blunt key-guessing.
4. **Staff PIN hashing** — when staff login lands, store salted argon2/bcrypt
   hashes (schema already uses `pin_hash`, not plaintext).
5. Wire `FlutterError.onError` to a real crash reporter (e.g. Sentry) for release.

## 12. Change Log

| Date | Phase | Change |
|---|---|---|
| 2026-07-12 | feat | **Admin dashboard (Flutter Web, in-repo).** Separate entry point `lib/admin/admin_main.dart` (`flutter build web -t lib/admin/admin_main.dart` — tree-shaken out of the mobile app). `AdminApp` → Supabase email/password login → role gate (`app_metadata.role=='admin'`) → dashboard: **Licenses** tab (all keys: shop/plan/status/expiry/device), **Payments** tab (license_payments, Approve→extend), **Generate key** FAB (shop_id/plan/months). All privileged ops go through a new **`admin` Edge Function** (`supabase/functions/admin/index.ts`) that verifies the admin JWT and uses the service role (actions: list_licenses, list_payments, create_license, renew_license → reuses the `0004` SQL fns; renew optionally marks the payment reconciled). Service key never touches the client. Enabled the `web` platform (`flutter create --platforms=web`). Admin web build verified (`✓ Built build/web`); 62 POS tests still pass. SETUP (user): deploy `supabase functions deploy admin`; create a Supabase auth user and set its `app_metadata.role='admin'`; run the admin app with `--dart-define-from-file=env.local.json`; deploy the web build to any static host (Cloudflare Pages/Vercel/Netlify). |
| 2026-07-12 | feat | **Renewal payment instructions + support contact (vendor config).** New backend `app_config` table (migration `0006_app_config.sql`: key/value, public-read RLS, service-role write, seeded with placeholder KBZPay/WavePay name+number + support Viber). App: `VendorConfig` model + `VendorConfigRepository` (fetch from `app_config` when online, cache in `AppSettings`, offline fallback) + `vendorConfigProvider`. License renewal dialog now shows a "Transfer license fee to: <method> · <number> · <name>" card (with copy button) for the selected KBZPay/WavePay method, and the reference field became "Transaction ID (last 6 digits)" (digits-only, max 6). Settings gains a Support tile (Company Viber, tap-to-copy). 62 tests pass (added 3 vendor-config tests). NOTE: `0006` **not yet applied to live DB** (classifier blocks agent `db push`) — run it + edit the seeded placeholder values with your real accounts; until then the app shows no pay-to card (empty config). |
| 2026-07-12 | feat | **Sell search/filter + shop-level stock toggle.** (1) Sell screen gains a search bar + category filter chips (own `sellSearchProvider`/`sellCategoryProvider`/`sellProductsProvider` so it doesn't share state with the Inventory tab). (2) "Track stock" shop setting (`shop.track_stock`, default on; `SettingsRepository.trackStock/setTrackStock/watchTrackStock` + `trackStockProvider`). When **off** (invoice-only): Sell hides out-of-stock marks, product editor hides qty/reorder, Inventory hides low-stock banner + badges, Analytics hides the Stock-value card, and `finalizeSale(trackStock:false)` skips the stock movement + decrement. SwitchListTile in Settings. 59 tests pass (added invoice-only finalizeSale test; smoke test overrides the new Drift `trackStock`/`categories` stream providers to avoid fake-clock query-stream timer leaks). |
| 2026-07-12 | feat | **Data backup + hybrid license online-renewal.** (1) Backup: `BackupService` exports all business tables to a pretty JSON envelope (excludes `app_settings`/`outbox` so device id + license survive), shared via `share_plus` (→ Viber My Notes etc.); import via `file_picker` does a **replace-all** restore inside one transaction after a confirm dialog. New `BackupScreen` + Settings tile. Added deps `share_plus`, `file_picker`. (2) Hybrid license: `LicenseController.refreshOnline()` re-calls `activate` (same key+device) to pick up an admin-approved extension; License screen gains a "Check for renewal" button + a KPay/WavePay→admin-approval hint next to the existing renewal-payment recorder. 58 tests pass (added 3 backup round-trip/isolation/validation tests). NOTE: `share_plus`/`file_picker` add iOS/Android platform plugins — first run rebuilds native; document-picker/share work on-device (not in widget tests). |
| 2026-07-12 | feat | **Credit sales surfaced in Invoices + Analytics.** Invoices: All/Credit filter chips, a credit badge (red=owed, green=settled) + customer name + "Owed" amount on credit rows. Analytics: `SaleRow` extended with `paid`+`paymentMethod`; `AnalyticsSummary` gains `creditSales`, `creditOutstanding`, and `collected` (= revenue − outstanding); two new KPI cards (Collected, Credit outstanding). `revenue` still counts full billed amount (accrual). 55 tests pass (added 1 analytics credit test; updated existing SaleRow literals via a `sale()` helper). |
| 2026-07-12 | feat | **Shop profile editor + Credit book (အကြွေး).** (1) Shop profile: `ShopProfileScreen` wired to the previously-dead Settings row (name/phone/address/receipt-footer → `saveShopProfile`, invalidates `shopProfileProvider` so receipts refresh). (2) Credit feature: new synced Drift table `credit_payments` (schemaVersion 1→2 with `onUpgrade`; sync mapper + Supabase migration `0005_credit.sql`). A credit sale reuses `sales` (`payment_method='credit'`, `customer_name`, `paid < total`); `SalesRepository` now records the payment row as the actual tender (`min(paid,total)`) not always `total`. `CreditRepository.aggregate` folds credit sales − repayments into per-customer outstanding; `CreditScreen`/`CreditCustomerScreen` (list + detail + record-repayment dialog) reachable from Settings → Credit book (keeps 5-tab nav). Checkout adds a 'credit' method with customer-name + partial "paid now" fields. 54 tests pass (added 7 credit tests). NOTE: `0005_credit.sql` **not yet applied to live DB** (classifier blocked agent `db push`); run `supabase db push` (or paste the SQL) before credit repayments will sync — feature is fully functional offline meanwhile. |
| 2026-07-12 | 4+5 | **Live backend deployed & verified** against project `gnikispsurwrmkspuisj` (GoldPOSMM). Applied migrations `0003_licensing.sql` + `0004_license_admin.sql` via `supabase db push` (0001/0002 already present, re-applied idempotently; migration tracking table now records 0001–0004). Deployed `activate` Edge Function. Enabled Anonymous sign-in (Auth config `external_anonymous_users_enabled=true`). End-to-end verification: (a) anon session → insert/select/delete on `products` succeeds (201/200/204) confirming `0002` dev-open RLS write path; (b) `activate` with seeded `DEMO-KEY-2026` → `ok:true` (shop `demo-shop`, monthly, active), bogus key → `invalid_key`. This clears the prior "pending on user / untested against live DB" NOTEs on Phases 4 & 5. NOTE: activate test bound `DEMO-KEY-2026` to throwaway device `verify-device-001`; reset before app-side demo with `update licenses set device_id=null, last_verified_at=null where key='DEMO-KEY-2026';`. Dev-open policies (`0002`) still active — drop before production. |
| 2026-07-10 | 0 | Spec created; stack = Flutter + Supabase decided. |
| 2026-07-10 | fix | Locale robustness: locale now **persisted** (AppSettings `app.locale`) via `LocaleController` (StateNotifier, default 'my') + `localeResolutionCallback` forcing the chosen locale so the device/system locale can never leak in (root cause of the transient English flip on an en-US emulator). Removed old ephemeral `localeProvider`. Fixed untranslated `settingsSync` ("Cloud sync" → "Cloud ချိတ်ဆက်မှု"). Added `create_license`/`renew_license` admin SQL (`0004_license_admin.sql`, service-role only). 47 tests pass (added 3 locale tests). NOTE: iOS simulator blocked by macOS Sequoia codesign bug (`com.apple.provenance` on Flutter.framework, system re-applies — unrelated to app code); Android emulator verified working. |
| 2026-07-10 | 1+ | Category management (deferred Phase 1 item, now done): `deleteCategory` (tombstone + outbox); categories screen (list, add/edit dialog, delete-with-confirm); product form category dropdown (uncategorized default, guards deleted categories); inventory category filter chips + `inventoryCategoryProvider`; manage-categories app-bar action. 44 tests pass (added 3 category repo tests). |
| 2026-07-10 | 7 | Hardening: i18n parity test (en/my key parity + no-empty + placeholder match — 3 tests), widget smoke test (boot → sell + 5-tab nav), global error handling (`runZonedGuarded` + `FlutterError.onError`, Supabase-init try/catch so backend failure never blocks offline), release polish (app display name "MM POS" on Android/iOS), README, security review (§13). 41 tests pass; `flutter analyze` clean. |
| 2026-07-10 | 6 | Analytics: pure `computeAnalytics` (revenue, sales count, discounts, COGS/profit, zero-filled daily series, top-N products by revenue, stock value) — 5 tests; `AnalyticsRepository` (offline reads from Drift); providers with Today/7d/30d range selector, auto-refresh on sales change. Dashboard: 4 KPI cards, fl_chart daily-revenue bar chart, top-products list. Fully offline (no backend). 37 tests pass. |
| 2026-07-10 | 5 | Licensing: pure `computeLicenseStatus` (active/grace/expired/none, 7-day grace) — 5 tests; `CachedLicense` model + `LicenseRepository` (activate via `activate` Edge Function when backend, else 14-day local trial; cache in AppSettings JSON; device-id binding; `recordRenewalPayment` → synced `license_payments` table); `LicenseController` binds `shopId` + gates selling. UI: license screen (status card, key activation, renewal-payment dialog, deactivate), settings tile with status, **read-only banner on sell + checkout blocked past grace**. Supabase: migration `0003_licensing.sql` (licenses + license_payments + RLS, `auth_shop_id()` reads app_metadata, dev seed key `DEMO-KEY-2026`), `activate` Edge Function (validates key, binds device, sets `app_metadata.shop_id`). App keeps license+sync controllers alive at launch. 32 tests pass (added 10). NOTE: Edge Function deploy + migration `0003` apply pending on user; online activation untested against live DB. |
| 2026-07-10 | 4 | Sync engine: Supabase migrations `0001_init.sql` (7 tables snake_case, indexes, shop-isolation RLS via `auth_shop_id()` JWT claim) + `0002_dev_open_policies.sql` (dev-only). Client: `SyncEngine` (outbox drain → push; pull with per-table `updated_at` cursor + last-write-wins merge), `SyncRemote` interface + `SupabaseSyncRemote`, explicit per-table `SyncTableDef` mappers (camel↔snake, ISO timestamps), sync cursors in `AppSettings`. `SyncController` (Riverpod) with connectivity_plus triggers + 5-min timer + anonymous-auth bootstrap. Settings "Cloud sync" tile (status + manual sync). Local run via `env.local.json` (gitignored) + `run.sh --dart-define-from-file`. Credentials verified live (auth health 200). 22 tests pass (added 5 sync tests: push/pull/LWW/cursor/tombstone). NOTE: end-to-end against live DB pending user applying migrations + enabling anonymous sign-in (see supabase/README.md). |
| 2026-07-10 | 3 | Invoices & printing: `ReceiptData`/`ReceiptFormatter` (pure, width-aware 58/80mm column layout — 5 tests), `AppSettings` KV table + `SettingsRepository` (printer/paper/shop config), `PrinterService` (print_bluetooth_thermal: pair/connect/write), **Burmese raster path** — `renderReceiptImage` draws the receipt via dart:ui (Noto/Pyidaungsu fallback) → ESC/POS `imageRaster` so Burmese prints on fontless printers; receipts use ASCII 'Ks' to keep money columns aligned. Invoices list + detail screens, reprint, printer settings screen (paper toggle, paired-device picker, test print), auto-print on checkout when a printer is set. Android BT permissions + iOS Bluetooth usage strings added. 17 tests pass. NOTE: on-device BT print not yet verified on real hardware (needs a paired printer). |
| 2026-07-10 | 2 | Sales: added `Sales`/`SaleItems`/`Payments` tables (sales append-only). `CartNotifier` (Riverpod) for the in-progress order, `SalesRepository.finalizeSale` — one transaction writes sale + items + payment + stock_movements + decrements stock_levels + enqueues all to Outbox. Per-shop/day invoice numbers `INV-yyyyMMdd-NNN`. Sell screen: product grid, tap-to-add, cart bar, checkout bottom sheet (qty steppers, discount, 5 payment methods incl. KBZPay/WavePay/AYAPay/CBPay, cash amount+change). 12 tests pass (added 5 checkout tests: totals/stock, discount, invoice increment, empty-cart guard, outbox). Digital payments assumed record-only for v1. |
| 2026-07-10 | 1 | Inventory: `InventoryRepository` (offline-first — writes Drift in a transaction + enqueues Outbox), `ProductWithStock` read model, Riverpod providers (products stream, search filter, low-stock count, categories), inventory list screen (search, low-stock banner + per-row stock badge, tap-to-edit), add/edit product form, demo seed (6 Myanmar minimart items). 7 tests pass (Money + repository: persist/outbox/low-stock/tombstone/shop-scoping). NOTE: category management UI still pending (repo method exists). |
| 2026-07-10 | 0 | Scaffolded Flutter app (`mm_pos`, org com.mmpos, android+ios). Added deps: riverpod, go_router, drift+sqlite3, supabase_flutter, connectivity_plus, intl, uuid, fl_chart, esc_pos_utils_plus, print_bluetooth_thermal. Built theme, Money value object, Env config, l10n (en/my) with ARB + gen_l10n, Drift DB skeleton (categories/products/stock_levels/stock_movements/outbox with SyncColumns), Riverpod providers, go_router shell (5 tabs, rail on tablet / bottom bar on phone), 5 placeholder feature screens. `flutter analyze` clean; Money unit tests pass. Supabase init is gated on --dart-define so app runs fully offline. |
