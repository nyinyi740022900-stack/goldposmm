-- PRODUCTION HARDENING: remove the permissive dev-open policies so each shop
-- can only see its own rows. Enforcement then relies on `shop_isolation`
-- (shop_id = auth_shop_id() JWT claim), which every user gets via `activate`
-- (paid keys) or `start_trial` (trials).
--
-- ⚠️ Apply this ONLY after `start_trial` is deployed and you've verified that
-- new installs (trial + paid) sync correctly — otherwise a user without a
-- shop_id claim will be unable to push/pull.

do $$
declare t text;
begin
  foreach t in array array[
    'categories','products','stock_levels','stock_movements',
    'sales','sale_items','payments','license_payments','credit_payments'
  ]
  loop
    execute format('drop policy if exists dev_open on %I;', t);
  end loop;
end $$;
