-- Phase 5 — licensing tables + JWT claim wiring.

-- Read shop_id from either a top-level claim or app_metadata (the activate
-- Edge Function stores it in the user's app_metadata).
create or replace function auth_shop_id() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true)::json ->> 'shop_id', ''),
    nullif(current_setting('request.jwt.claims', true)::json
             -> 'app_metadata' ->> 'shop_id', ''),
    ''
  );
$$;

-- Server-authoritative licenses. Written only by the service role (Edge
-- Function); clients may read their own shop's row.
create table if not exists licenses (
  id               uuid primary key default gen_random_uuid(),
  shop_id          text not null,
  key              text not null unique,
  plan             text not null default 'monthly',   -- monthly | yearly
  status           text not null default 'active',    -- active | expired | grace
  device_id        text,
  activated_at     timestamptz,
  expires_at       timestamptz not null,
  last_verified_at timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  is_deleted       boolean not null default false
);

alter table licenses enable row level security;
drop policy if exists license_read on licenses;
create policy license_read on licenses
  for select to authenticated
  using (shop_id = auth_shop_id());

-- Locally-recorded renewal payments (synced from the client for reconciliation).
create table if not exists license_payments (
  id          text primary key,
  shop_id     text not null,
  license_key text not null,
  method      text not null,
  amount      integer not null,
  ref_no      text,
  note        text,
  reconciled  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  is_deleted  boolean not null default false
);
create index if not exists idx_license_payments_shop_updated
  on license_payments (shop_id, updated_at);

alter table license_payments enable row level security;
drop policy if exists shop_isolation on license_payments;
create policy shop_isolation on license_payments
  for all to authenticated
  using (shop_id = auth_shop_id())
  with check (shop_id = auth_shop_id());

-- If you applied 0002 (dev-open), also open license_payments for testing:
drop policy if exists dev_open on license_payments;
create policy dev_open on license_payments
  for all to authenticated using (true) with check (true);

-- ⚠️ DEV SEED — a demo license key so you can test online activation.
-- Remove before production.
insert into licenses (shop_id, key, plan, status, expires_at, activated_at)
values ('demo-shop', 'DEMO-KEY-2026', 'monthly', 'active',
        now() + interval '30 days', now())
on conflict (key) do nothing;
