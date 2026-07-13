-- Audit log of every key issue / renewal the admin performs, so the dashboard
-- can show a history. Written by the `admin` Edge Function (service role).

create table if not exists license_events (
  id         uuid primary key default gen_random_uuid(),
  device_id  text,
  shop_name  text,
  key        text,
  action     text not null,          -- 'issue' | 'extend'
  months     int,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_license_events_created
  on license_events (created_at desc);

alter table license_events enable row level security;
-- No client policy → reads/writes are service-role (admin function) only.
