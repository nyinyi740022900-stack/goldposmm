-- Self-service subscription requests. A brand-new user with no key submits one
-- from the app (shop name, phone, chosen plan, payment proof + device id). The
-- admin reviews the payment and issues a key, which the vendor sends back.

create table if not exists license_requests (
  id         text primary key,
  shop_name  text not null,
  phone      text,
  plan       text not null default 'monthly',   -- monthly | yearly
  months     int  not null default 1,
  method     text,                              -- kbzpay | wavepay
  amount     integer,
  ref_no     text,                              -- transaction id (last 6)
  device_id  text,
  status     text not null default 'pending',   -- pending | fulfilled
  issued_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table license_requests enable row level security;

-- Anyone may submit a request (they have no shop/JWT claim yet).
drop policy if exists lr_insert on license_requests;
create policy lr_insert on license_requests
  for insert to anon, authenticated with check (true);

-- Reads + updates are service-role only (the admin Edge Function). With no
-- select/update policy, anon/authenticated clients cannot see others' requests.
