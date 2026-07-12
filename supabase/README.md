# Supabase setup

Project: `https://gnikispsurwrmkspuisj.supabase.co`

## 1. Apply the schema

In the Supabase dashboard → **SQL Editor**, run these in order:

1. `migrations/0001_init.sql` — tables, indexes, and production RLS
   (shop-isolation via a `shop_id` JWT claim; issued in Phase 5).
2. `migrations/0002_dev_open_policies.sql` — **DEV ONLY.** Lets any
   authenticated session read/write so you can test sync before licensing.
   Remove before production.

(Or, with the CLI linked: `supabase link` then `supabase db push`.)

## 2. Enable anonymous sign-in (for the dev phase)

Dashboard → **Authentication → Providers → Anonymous** → enable.
The app calls `signInAnonymously()` to get a session so the dev policies apply.

## 3. Run the app with credentials

```bash
./run.sh
```

This injects `env.local.json` (gitignored) via `--dart-define-from-file`.
Without it, the app runs fully offline and cloud sync stays disabled.

## 4. Verify

Sell something (or add a product) on one device, then pull-to-sync in
**Settings → Cloud sync → Sync now**. Rows appear in the Supabase Table Editor.

## Creating license keys (subscriptions)

A "license key" is just a row in the `licenses` table. Migration
`0004_license_admin.sql` adds two admin-only helper functions.

**Generate a key for a shop** (in SQL Editor):

```sql
-- 1 year, yearly plan:
select create_license('shop-0001', 'yearly', 12);
--> MMPOS-3F9A-1C7E-B204   (give this to the customer)

-- 1 month:
select create_license('shop-0002', 'monthly', 1);
```

`shop_id` is whatever id identifies that customer's shop (any stable string).
On activation the Edge Function binds the key to the first device and stamps
that `shop_id` into the user's JWT, so all their data scopes to it.

**Renew / extend** an existing key:

```sql
select renew_license('MMPOS-3F9A-1C7E-B204', 12);  -- +12 months
```

**The customer flow:** you send them the key → they open the app →
**Settings → License → enter key → Activate**. If online, it validates against
Supabase; offline, the app grants a 14-day trial until it can verify.

These functions are `SECURITY DEFINER` and `revoke`d from public, so only the
service role / SQL editor (you, the admin) can mint keys — never the app.

## Going to production

- Drop the dev policies (re-apply `0001` or write `0003_drop_dev_policies.sql`).
- Phase 5's `activate` Edge Function issues a JWT carrying `shop_id`, which the
  RLS policies in `0001` enforce for true multi-tenant isolation.
