-- Vendor-level configuration shown in the app: where shops send their license
-- renewal payments (the COMPANY's KBZPay/WavePay accounts) and the support
-- Viber contact. Editable from the admin side / SQL without shipping an app
-- update. Publicly readable (even pre-login) so the payment instructions are
-- always visible; only the service role may write.

create table if not exists app_config (
  key        text primary key,
  value      text not null default '',
  updated_at timestamptz not null default now()
);

alter table app_config enable row level security;
drop policy if exists app_config_read on app_config;
create policy app_config_read on app_config
  for select to anon, authenticated using (true);
-- No write policy → inserts/updates are service-role only (admin/SQL editor).

insert into app_config (key, value) values
  ('pay.kbzpay.name',   'YOUR COMPANY NAME'),
  ('pay.kbzpay.number', '09xxxxxxxxx'),
  ('pay.wavepay.name',  'YOUR COMPANY NAME'),
  ('pay.wavepay.number','09xxxxxxxxx'),
  ('support.viber',     '09xxxxxxxxx')
on conflict (key) do nothing;
