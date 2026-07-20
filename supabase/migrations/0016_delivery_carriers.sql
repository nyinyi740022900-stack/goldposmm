-- Phase 8 — delivery carrier credentials (Ninja Van, Royal Express, …).
--
-- These rows hold SECRETS (carrier API keys). They must never be readable by
-- the anon/authenticated client, so RLS is enabled with **no policy** → the
-- table is default-deny for everyone except the service role (which bypasses
-- RLS). The admin dashboard reads/writes them only through the `admin` Edge
-- Function, which runs with the service role and returns the key masked.
--
-- Waybill creation (future) will also go through an Edge Function that reads
-- the key here and calls the carrier API — the key never reaches the client.

create table if not exists delivery_carriers (
  id          uuid primary key default gen_random_uuid(),
  carrier     text not null,              -- 'ninja_van' | 'royal_express' | ...
  account_id  text,                       -- carrier account / client id
  api_key     text,                       -- SECRET — never returned to clients
  base_url    text,                       -- optional API base / sandbox url
  enabled     boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table delivery_carriers enable row level security;
-- Intentionally NO policy: default-deny for anon + authenticated. Only the
-- service role (Edge Function) may touch this table.
