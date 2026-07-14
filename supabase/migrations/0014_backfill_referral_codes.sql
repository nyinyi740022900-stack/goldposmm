-- Review follow-ups to 0013.

-- ---------------------------------------------------------------------------
-- Finding 2: widen the referral code space from 4 hex (65,536) to 6 hex
-- (16.7M) so collisions stay negligible as the shop base grows. Existing
-- REF-XXXX codes remain valid; only newly generated codes are longer.
-- ---------------------------------------------------------------------------
create or replace function gen_referral_code() returns text
language plpgsql
as $$
declare
  v_code text;
begin
  loop
    v_code := 'REF-' || upper(substr(md5(gen_random_uuid()::text), 1, 6));
    exit when not exists (select 1 from licenses where referral_code = v_code);
  end loop;
  return v_code;
end;
$$;

-- Backfill any licenses still missing a referral_code. 0013 backfilled every
-- row that existed then, but trials created between that deploy and the
-- start_trial redeploy could have a null. Idempotent.
update licenses
set referral_code = gen_referral_code()
where referral_code is null;

-- ---------------------------------------------------------------------------
-- Finding 1: serialize redemption so concurrent calls can't double-spend a
-- shop's balance. One locked function now owns the compute+redeem logic; both
-- the self-service RPC and the admin path go through it.
-- ---------------------------------------------------------------------------
create or replace function apply_referral_credit_for(p_shop_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_earned   integer;
  v_redeemed integer;
  v_balance  integer;
  v_price    integer;
  v_months   integer;
  v_amount   integer;
  v_key      text;
  v_expiry   timestamptz;
begin
  if p_shop_id is null or p_shop_id = '' then
    raise exception 'no shop context';
  end if;

  -- Transaction-scoped lock per shop: a second redemption for the same shop
  -- waits until the first commits, then reads the updated balance.
  perform pg_advisory_xact_lock(hashtext('referral_redeem:' || p_shop_id));

  select coalesce(sum(amount), 0) into v_earned
    from referral_commissions where referrer_shop_id = p_shop_id;
  select coalesce(sum(amount), 0) into v_redeemed
    from referral_redemptions where referrer_shop_id = p_shop_id;
  v_balance := v_earned - v_redeemed;

  select coalesce(nullif(value, '')::int, 10000) into v_price
    from app_config where key = 'price.monthly';
  v_price := coalesce(v_price, 10000);

  v_months := floor(v_balance::numeric / v_price);
  if v_months < 1 then
    return jsonb_build_object('months', 0, 'balance', v_balance,
                              'price', v_price);
  end if;
  v_amount := v_months * v_price;

  select key into v_key from licenses
    where shop_id = p_shop_id and coalesce(is_deleted, false) = false
    order by expires_at desc limit 1;
  if v_key is null then
    raise exception 'no license for shop';
  end if;

  v_expiry := renew_license(v_key, v_months);
  insert into referral_redemptions
    (referrer_shop_id, license_key, amount, months)
  values (p_shop_id, v_key, v_amount, v_months);

  return jsonb_build_object(
    'months', v_months, 'amount', v_amount, 'expires_at', v_expiry,
    'balance', v_balance - v_amount);
end;
$$;
revoke execute on function apply_referral_credit_for(text) from public;
grant  execute on function apply_referral_credit_for(text) to service_role;

-- Self-service redeem now just delegates to the locked function for the
-- caller's own shop.
create or replace function redeem_referral_balance() returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sid text := auth_shop_id();
begin
  if v_sid is null or v_sid = '' then
    raise exception 'no shop context';
  end if;
  return apply_referral_credit_for(v_sid);
end;
$$;
revoke execute on function redeem_referral_balance() from public;
grant  execute on function redeem_referral_balance() to authenticated;
