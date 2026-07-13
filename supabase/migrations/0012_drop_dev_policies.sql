-- PRODUCTION HARDENING: replace the permissive dev-open policies with proper
-- shop isolation on every synced table, so each shop can only see its own
-- rows. `0002` had dropped shop_isolation on the 7 core tables when it added
-- dev_open, so this re-creates it everywhere (not just drops dev_open —
-- dropping alone would leave the core tables with NO policy = default-deny).
--
-- Enforcement uses shop_isolation (shop_id = auth_shop_id() JWT claim). Every
-- user gets that claim via `activate` (paid keys) or `start_trial` (trials).
--
-- ⚠️ Apply this ONLY after verifying new installs (trial + paid) get a shop_id
-- claim and sync correctly — a user without the claim can't push/pull.

do $$
declare t text;
begin
  foreach t in array array[
    'categories','products','stock_levels','stock_movements',
    'sales','sale_items','payments','license_payments','credit_payments'
  ]
  loop
    execute format('alter table %I enable row level security;', t);
    execute format('drop policy if exists dev_open on %I;', t);
    execute format('drop policy if exists shop_isolation on %I;', t);
    execute format($f$
      create policy shop_isolation on %I
        for all to authenticated
        using (shop_id = auth_shop_id())
        with check (shop_id = auth_shop_id());
    $f$, t);
  end loop;
end $$;
