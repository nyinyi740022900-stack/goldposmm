-- Phase D admin extras: a human-readable shop name on licenses (so the admin
-- console shows who a device/payment belongs to), and seeded renewal prices in
-- app_config (edited from the admin dashboard).

alter table licenses add column if not exists shop_name text;

-- Recreate create_license with an optional shop name.
drop function if exists create_license(text, text, int);
create or replace function create_license(
  p_shop_id   text,
  p_plan      text default 'monthly',
  p_months    int  default 1,
  p_shop_name text default null
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
begin
  v_key := 'MMPOS-'
    || upper(substr(md5(gen_random_uuid()::text), 1, 4)) || '-'
    || upper(substr(md5(gen_random_uuid()::text), 1, 4)) || '-'
    || upper(substr(md5(gen_random_uuid()::text), 1, 4));

  insert into licenses (shop_id, shop_name, key, plan, status, expires_at, activated_at)
  values (p_shop_id, p_shop_name, v_key, p_plan, 'active',
          now() + (p_months || ' months')::interval, null);

  return v_key;
end;
$$;
revoke execute on function create_license(text, text, int, text) from public;

-- Renewal prices (kyat). Edit from Admin → Config or here.
insert into app_config (key, value) values
  ('price.monthly', '10000'),
  ('price.yearly',  '100000')
on conflict (key) do nothing;
