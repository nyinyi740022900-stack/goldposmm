-- Phase 6 — single-level referral commission.
--
-- Every shop gets a shareable `referral_code`. A brand-new shop may type a
-- referrer's code into its subscription request. From then on, EVERY time that
-- referred shop actually pays (a fulfilled license_request), the referrer earns
-- a commission = paid_amount * referral.rate. Commissions are immutable "earn"
-- rows; the referrer redeems the accumulated balance toward their own license
-- renewal (recorded in referral_redemptions). Balance = earned - redeemed.
--
-- IMPORTANT (anti-pyramid): commission is only ever created on a REAL payment
-- for the referred shop — never for recruitment alone. The `source_request_id`
-- unique constraint ties one commission to one paid request, so a payment can
-- never be double-counted.

-- ---------------------------------------------------------------------------
-- 1. Shareable code on each license.
-- ---------------------------------------------------------------------------
alter table licenses add column if not exists referral_code text;

-- Readable, easy-to-dictate code: REF-XXXX (hex). Retries on the (rare) clash.
create or replace function gen_referral_code() returns text
language plpgsql
as $$
declare
  v_code text;
begin
  loop
    v_code := 'REF-' || upper(substr(md5(gen_random_uuid()::text), 1, 4));
    exit when not exists (select 1 from licenses where referral_code = v_code);
  end loop;
  return v_code;
end;
$$;

-- Backfill existing licenses.
update licenses set referral_code = gen_referral_code()
  where referral_code is null;

create unique index if not exists idx_licenses_referral_code
  on licenses (referral_code) where referral_code is not null;

-- The referrer's code the new shop typed at subscription time.
alter table license_requests add column if not exists referred_by_code text;

-- ---------------------------------------------------------------------------
-- 2. Referral links (who referred whom) — single level, one referrer per shop.
-- ---------------------------------------------------------------------------
create table if not exists referrals (
  id                uuid primary key default gen_random_uuid(),
  referrer_shop_id  text not null,
  referred_shop_id  text not null unique,   -- a shop can be referred only once
  referral_code     text not null,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now()
);
create index if not exists idx_referrals_referrer
  on referrals (referrer_shop_id);

alter table referrals enable row level security;
-- A referrer may see the shops they referred; nobody sees who referred them.
drop policy if exists referrals_read on referrals;
create policy referrals_read on referrals
  for select to authenticated
  using (referrer_shop_id = auth_shop_id());
-- Writes are service-role only (admin Edge Function).

-- ---------------------------------------------------------------------------
-- 3. Commission earn ledger — one immutable row per real payment.
-- ---------------------------------------------------------------------------
create table if not exists referral_commissions (
  id                uuid primary key default gen_random_uuid(),
  referrer_shop_id  text not null,
  referred_shop_id  text not null,
  license_key       text,
  base_amount       integer not null,       -- what the referred shop paid (Ks)
  rate              numeric not null,        -- e.g. 0.15
  amount            integer not null,        -- round(base_amount * rate) (Ks)
  source_request_id text unique,             -- ties to the paid request (dedup)
  created_at        timestamptz not null default now()
);
create index if not exists idx_ref_comm_referrer
  on referral_commissions (referrer_shop_id, created_at desc);

alter table referral_commissions enable row level security;
drop policy if exists ref_comm_read on referral_commissions;
create policy ref_comm_read on referral_commissions
  for select to authenticated
  using (referrer_shop_id = auth_shop_id());

-- ---------------------------------------------------------------------------
-- 4. Redemptions — balance drawn down to extend the referrer's own license.
-- ---------------------------------------------------------------------------
create table if not exists referral_redemptions (
  id                uuid primary key default gen_random_uuid(),
  referrer_shop_id  text not null,
  license_key       text not null,
  amount            integer not null,        -- Ks spent from balance
  months            integer not null,        -- license months granted
  created_at        timestamptz not null default now()
);
create index if not exists idx_ref_redeem_referrer
  on referral_redemptions (referrer_shop_id, created_at desc);

alter table referral_redemptions enable row level security;
drop policy if exists ref_redeem_read on referral_redemptions;
create policy ref_redeem_read on referral_redemptions
  for select to authenticated
  using (referrer_shop_id = auth_shop_id());

-- ---------------------------------------------------------------------------
-- 5. Self-service balance readout for the app (own shop only).
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER + auth_shop_id() so a shop can only ever read its own totals.
create or replace function my_referral_balance() returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  with s as (select auth_shop_id() as sid)
  select jsonb_build_object(
    'shop_id', s.sid,
    'earned',  coalesce((select sum(amount) from referral_commissions
                          where referrer_shop_id = s.sid), 0),
    'redeemed',coalesce((select sum(amount) from referral_redemptions
                          where referrer_shop_id = s.sid), 0),
    'active_referrals', coalesce((select count(*) from referrals
                          where referrer_shop_id = s.sid and is_active), 0)
  ) || jsonb_build_object(
    'balance',
      coalesce((select sum(amount) from referral_commissions
                where referrer_shop_id = s.sid), 0)
    - coalesce((select sum(amount) from referral_redemptions
                where referrer_shop_id = s.sid), 0)
  )
  from s;
$$;
revoke execute on function my_referral_balance() from public;
grant  execute on function my_referral_balance() to authenticated;

-- Self-service redeem: convert the referrer's balance into license months on
-- their OWN license. Whole months only (price.monthly each); the remainder
-- stays as balance. Draws only from the caller's own shop via auth_shop_id().
create or replace function redeem_referral_balance() returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sid     text := auth_shop_id();
  v_earned  integer;
  v_redeemed integer;
  v_balance integer;
  v_price   integer;
  v_months  integer;
  v_amount  integer;
  v_key     text;
  v_expiry  timestamptz;
begin
  if v_sid is null or v_sid = '' then
    raise exception 'no shop context';
  end if;

  select coalesce(sum(amount), 0) into v_earned
    from referral_commissions where referrer_shop_id = v_sid;
  select coalesce(sum(amount), 0) into v_redeemed
    from referral_redemptions where referrer_shop_id = v_sid;
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
    where shop_id = v_sid and coalesce(is_deleted, false) = false
    order by expires_at desc limit 1;
  if v_key is null then
    raise exception 'no license for shop';
  end if;

  v_expiry := renew_license(v_key, v_months);
  insert into referral_redemptions
    (referrer_shop_id, license_key, amount, months)
  values (v_sid, v_key, v_amount, v_months);

  return jsonb_build_object(
    'months', v_months, 'amount', v_amount, 'expires_at', v_expiry,
    'balance', v_balance - v_amount);
end;
$$;
revoke execute on function redeem_referral_balance() from public;
grant  execute on function redeem_referral_balance() to authenticated;

-- ---------------------------------------------------------------------------
-- 6. create_license: hand out a referral_code on every new license.
-- ---------------------------------------------------------------------------
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

  insert into licenses
    (shop_id, shop_name, key, plan, status, expires_at, activated_at,
     referral_code)
  values
    (p_shop_id, p_shop_name, v_key, p_plan, 'active',
     now() + (p_months || ' months')::interval, null,
     gen_referral_code());

  return v_key;
end;
$$;
revoke execute on function create_license(text, text, int, text) from public;

-- ---------------------------------------------------------------------------
-- 7. Config: enable + commission rate (edit from Admin → Config).
-- ---------------------------------------------------------------------------
insert into app_config (key, value) values
  ('referral.enabled', 'true'),
  ('referral.rate',    '0.15')      -- 15% of each referred payment
on conflict (key) do nothing;
