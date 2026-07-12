# MM POS — Myanmar Retail Point of Sale

An **offline-first** POS app for Myanmar retailers (Android + iOS). Sell without
internet; sync to the cloud when connected. Burmese-first UI, Bluetooth thermal
receipt printing, subscription licensing, and offline sales analytics.

> Full technical spec and change log: [PROJECT_SPEC.md](PROJECT_SPEC.md).

## Features

- **Inventory** — products, categories, stock levels, low-stock alerts, barcodes.
- **Sell** — fast product grid → cart → checkout. Cash / KBZPay / WavePay /
  AYAPay / CBPay. Append-only sales, automatic stock decrement, invoice numbers.
- **Invoices & printing** — Bluetooth ESC/POS (58/80mm) with a **Burmese raster
  fallback** so receipts print correctly on fontless printers. Reprint any sale.
- **Cloud sync** — offline-first outbox → Supabase, pull/merge with
  last-write-wins. Works across devices for one shop.
- **Licensing** — online activation, device binding, 7-day offline grace, then
  read-only until renewed. Record renewal payments locally.
- **Analytics** — revenue, profit, sales count, stock value, daily-revenue chart,
  top products. Fully offline.
- **Bilingual** — Burmese (my) + English (en), switchable live.

## Tech stack

Flutter · Riverpod · go_router · Drift (SQLite) · Supabase · fl_chart ·
esc_pos_utils_plus + print_bluetooth_thermal.

## Getting started

```bash
flutter pub get
dart run build_runner build      # generate Drift + code
flutter gen-l10n                 # generate localizations

# Run offline (no backend needed):
flutter run

# Run with cloud sync (see supabase/README.md to set up the project first):
./run.sh
```

Backend credentials go in `env.local.json` (gitignored) — see
[supabase/README.md](supabase/README.md).

## Project layout

```
lib/
  core/       theme, Money, env, providers, router
  data/
    local/    Drift database + tables
    repositories/  inventory, sales, settings, analytics, license
    sync/     sync engine, mappers, providers
  features/
    sell/ inventory/ invoices/ printing/ analytics/ license/ settings/
  l10n/       ARB files (en, my)
supabase/     migrations + activate Edge Function
test/         unit, repository, sync, i18n, and widget tests
```

## Testing

```bash
flutter analyze
flutter test
```

## Development conventions

- Money is stored as **integer kyat** (no floats) via the `Money` value object.
- The UI never calls the network directly — it reads/writes Drift; the
  `SyncEngine` moves data to/from Supabase.
- Every user-facing string goes through `AppLocalizations` (no hardcoded text).
- Sales rows are **append-only**; corrections are reversal records.
