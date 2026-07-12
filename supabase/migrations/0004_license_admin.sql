-- Phase 5 — license administration helpers.
--
-- Creating a "license key" = inserting a row into the `licenses` table with a
-- unique `key`. These SECURITY DEFINER functions make that a one-liner and are
-- locked down so only the service role / SQL editor (an admin) can call them —
-- never the app's anon/authenticated clients.

-- create_license(shop_id, plan, months) -> returns the generated key.
-- Example:  select create_license('shop-0001', 'yearly', 12);
create or replace function create_license(
  p_shop_id text,
  p_plan    text default 'monthly',   -- 'monthly' | 'yearly'
  p_months  int  default 1
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
begin
  -- Readable key: MMPOS-XXXX-XXXX-XXXX (hex, easy to type/dictate).
  v_key := 'MMPOS-'
    || upper(substr(md5(gen_random_uuid()::text), 1, 4)) || '-'
    || upper(substr(md5(gen_random_uuid()::text), 1, 4)) || '-'
    || upper(substr(md5(gen_random_uuid()::text), 1, 4));

  insert into licenses (shop_id, key, plan, status, expires_at, activated_at)
  values (p_shop_id, v_key, p_plan, 'active',
          now() + (p_months || ' months')::interval, null);

  return v_key;
end;
$$;

-- renew_license(key, months) -> returns the new expiry.
-- Extends from whichever is later: current expiry or now (no lost days,
-- no stacking a grace gap). Example: select renew_license('MMPOS-....', 12);
create or replace function renew_license(
  p_key    text,
  p_months int
) returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expiry timestamptz;
begin
  update licenses
  set expires_at = greatest(expires_at, now()) + (p_months || ' months')::interval,
      status     = 'active',
      updated_at = now()
  where key = p_key
  returning expires_at into v_expiry;

  if v_expiry is null then
    raise exception 'license key % not found', p_key;
  end if;
  return v_expiry;
end;
$$;

-- Lock down: only the service role (and SQL editor) may generate/renew keys.
revoke execute on function create_license(text, text, int) from public;
revoke execute on function renew_license(text, int)        from public;
