-- ⚠️  DEV / TESTING ONLY — DO NOT SHIP TO PRODUCTION  ⚠️
--
-- The real shop-isolation policies in 0001 require a JWT `shop_id` claim,
-- which is issued by the license-activation Edge Function in Phase 5. Until
-- then there is no claim, so those policies deny everything.
--
-- This migration temporarily lets any *authenticated* session (including an
-- anonymous sign-in) read/write all rows, so you can verify the sync engine
-- now. Enable anonymous sign-ins in Supabase → Authentication → Providers.
--
-- BEFORE PRODUCTION: run 0003_drop_dev_policies.sql (or re-apply 0001).

do $$
declare t text;
begin
  foreach t in array array[
    'categories','products','stock_levels','stock_movements',
    'sales','sale_items','payments'
  ]
  loop
    execute format('drop policy if exists shop_isolation on %I;', t);
    execute format('drop policy if exists dev_open on %I;', t);
    execute format($f$
      create policy dev_open on %I
        for all
        to authenticated
        using (true)
        with check (true);
    $f$, t);
  end loop;
end $$;
