-- Phase 9 — distinguish "will transfer" vs "cash on delivery" on an order.
--
-- Storefront guests were treated identically regardless of how they intend to
-- pay: both a "I'll transfer now" customer and a "pay the courier cash" one
-- landed as payment_status='unpaid' with no way to tell them apart. The shop
-- needs a different workflow for each (review a screenshot vs collect cash at
-- the door) — payment_method captures that distinction, separate from
-- payment_status (which stays about whether the money has actually arrived).

alter table orders add column if not exists payment_method text;
