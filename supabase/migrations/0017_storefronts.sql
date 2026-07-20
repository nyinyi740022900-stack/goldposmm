-- Phase 9 — B2B2C web storefront.
--
-- Each shop can publish a public catalog at a dynamic URL: /{slug}. A shop
-- owner (authenticated) manages their own storefront row; customers are
-- anonymous and never touch these tables directly — the public catalog read
-- and guest-order write both go through the `storefront` Edge Function (service
-- role), which exposes only safe fields and never any secret.

create table if not exists storefronts (
  shop_id      text primary key,
  slug         text unique not null,
  display_name text,
  phone        text,
  address      text,
  pay_kpay     text,          -- KBZPay number to show customers
  pay_wave     text,          -- WavePay number to show customers
  enabled      boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists idx_storefronts_slug on storefronts (slug);

alter table storefronts enable row level security;
-- A shop owner reads/writes only their own storefront row. Public (anon)
-- access is intentionally NOT granted here — it goes through the Edge Function.
drop policy if exists storefront_owner on storefronts;
create policy storefront_owner on storefronts
  for all to authenticated
  using (shop_id = auth_shop_id()) with check (shop_id = auth_shop_id());

-- Slug generator: a URL-safe handle from the shop name, with a short random
-- suffix to guarantee uniqueness.
create or replace function gen_storefront_slug(p_name text) returns text
language plpgsql
as $$
declare
  v_base text;
  v_slug text;
begin
  v_base := lower(regexp_replace(coalesce(nullif(trim(p_name), ''), 'shop'),
                                 '[^a-z0-9]+', '-', 'gi'));
  v_base := trim(both '-' from v_base);
  if v_base = '' then v_base := 'shop'; end if;
  loop
    v_slug := v_base || '-' || substr(md5(gen_random_uuid()::text), 1, 4);
    exit when not exists (select 1 from storefronts where slug = v_slug);
  end loop;
  return v_slug;
end;
$$;
