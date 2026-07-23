-- Phase 2 — refunds.
--
-- A refund is a normal append-only `sales` row with negated subtotal/
-- discount/total/paid, pointing back at the sale it reverses via
-- refund_of_sale_id. The original sale is never mutated (sales stay an
-- immutable ledger) — this nets out correctly in revenue/profit reporting
-- with no special-casing, the same way any other sale row would.

alter table sales add column if not exists refund_of_sale_id text;
create index if not exists idx_sales_refund_of on sales (refund_of_sale_id)
  where refund_of_sale_id is not null;
