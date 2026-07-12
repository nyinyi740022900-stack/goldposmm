# MM POS — Admin dashboard (Flutter Web)

Vendor console for managing licenses. Separate from the POS app: its own entry
point (`admin_main.dart`), tree-shaken out of the mobile build. All privileged
work goes through the `admin` Edge Function (service role stays server-side).

## What it does
- **Licenses** — every key: shop, plan, status, expiry, bound device.
- **Payments** — renewal payments shops recorded; **Approve** extends the
  license (calls `renew_license`) and marks the payment reconciled.
- **Generate key** — mint a key for a shop (`create_license`).

## One-time setup

1. **Deploy the backend function**
   ```bash
   supabase functions deploy admin
   ```
   (Also apply migrations first if not done: `supabase db push`.)

2. **Create an admin user** (Supabase Dashboard → Authentication → Add user,
   or SQL), then grant the admin role in SQL Editor:
   ```sql
   update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                           || '{"role":"admin"}'::jsonb
   where email = 'admin@yourcompany.com';
   ```
   The `admin` function rejects anyone without `app_metadata.role = 'admin'`.

## Run locally
```bash
flutter run -d chrome -t lib/admin/admin_main.dart \
  --dart-define-from-file=env.local.json
```

## Deploy the dashboard (static hosting)
```bash
flutter build web -t lib/admin/admin_main.dart \
  --dart-define-from-file=env.local.json
# upload build/web/ to Cloudflare Pages / Vercel / Netlify / GitHub Pages
```
Only the anon key ships in the web bundle (safe — the `admin` function enforces
the admin check). Never put the service-role key in this app.
