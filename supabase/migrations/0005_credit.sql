-- Credit book (အကြွေး): repayments a customer makes against outstanding
-- credit. Credit sales themselves live in `sales` (payment_method = 'credit'
-- with paid < total); this table records the repayments. Synced like every
-- other ledger table, with the same shop-isolation RLS.

create table if not exists credit_payments (
  id            text primary key,
  shop_id       text not null,
  customer_name text not null,
  method        text not null default 'cash',
  amount        integer not null,
  note          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  is_deleted    boolean not null default false
);
create index if not exists idx_credit_payments_shop_updated
  on credit_payments (shop_id, updated_at);

alter table credit_payments enable row level security;
drop policy if exists shop_isolation on credit_payments;
create policy shop_isolation on credit_payments
  for all to authenticated
  using (shop_id = auth_shop_id())
  with check (shop_id = auth_shop_id());

-- If you applied 0002 (dev-open), also open credit_payments for testing:
drop policy if exists dev_open on credit_payments;
create policy dev_open on credit_payments
  for all to authenticated using (true) with check (true);
