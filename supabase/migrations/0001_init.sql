-- MM POS — initial schema + Row Level Security
-- Mirrors the on-device Drift schema. Column names are snake_case; the client
-- sync codec maps camelCase <-> snake_case.
--
-- Sync model: every table carries shop_id, updated_at (last-write-wins),
-- is_deleted (tombstone). `dirty` is client-only and never sent.

create extension if not exists "pgcrypto";

-- Helper: the caller's shop id, taken from the JWT claim set at license
-- activation (Phase 5). Anon requests have no claim and see nothing.
create or replace function auth_shop_id() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true)::json ->> 'shop_id', ''),
    ''
  );
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists categories (
  id          text primary key,
  shop_id     text not null,
  name        text not null,
  sort        integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  is_deleted  boolean not null default false
);

create table if not exists products (
  id          text primary key,
  shop_id     text not null,
  name        text not null,
  sku         text,
  barcode     text,
  category_id text,
  cost_price  integer not null default 0,
  sale_price  integer not null default 0,
  unit        text not null default 'pcs',
  image_path  text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  is_deleted  boolean not null default false
);

create table if not exists stock_levels (
  id            text primary key,
  shop_id       text not null,
  product_id    text not null,
  quantity      integer not null default 0,
  reorder_level integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  is_deleted    boolean not null default false
);

create table if not exists stock_movements (
  id          text primary key,
  shop_id     text not null,
  product_id  text not null,
  type        text not null,
  qty_delta   integer not null,
  unit_cost   integer not null default 0,
  ref_id      text,
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  is_deleted  boolean not null default false
);

create table if not exists sales (
  id             text primary key,
  shop_id        text not null,
  invoice_no     text not null,
  staff_id       text,
  subtotal       integer not null default 0,
  discount       integer not null default 0,
  tax            integer not null default 0,
  total          integer not null default 0,
  paid           integer not null default 0,
  change_due     integer not null default 0,
  payment_method text not null default 'cash',
  customer_name  text,
  note           text,
  finalized_at   timestamptz not null default now(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  is_deleted     boolean not null default false
);

create table if not exists sale_items (
  id             text primary key,
  shop_id        text not null,
  sale_id        text not null,
  product_id     text not null,
  name_snapshot  text not null,
  price_snapshot integer not null,
  qty            integer not null,
  line_total     integer not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  is_deleted     boolean not null default false
);

create table if not exists payments (
  id          text primary key,
  shop_id     text not null,
  sale_id     text not null,
  method      text not null,
  amount      integer not null,
  ref_no      text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  is_deleted  boolean not null default false
);

-- Indexes for the pull query (updated_at > cursor, scoped by shop).
create index if not exists idx_products_shop_updated on products (shop_id, updated_at);
create index if not exists idx_categories_shop_updated on categories (shop_id, updated_at);
create index if not exists idx_stock_levels_shop_updated on stock_levels (shop_id, updated_at);
create index if not exists idx_stock_movements_shop_updated on stock_movements (shop_id, updated_at);
create index if not exists idx_sales_shop_updated on sales (shop_id, updated_at);
create index if not exists idx_sale_items_shop_updated on sale_items (shop_id, updated_at);
create index if not exists idx_payments_shop_updated on payments (shop_id, updated_at);

-- ---------------------------------------------------------------------------
-- Row Level Security: a client may only touch rows for its own shop.
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'categories','products','stock_levels','stock_movements',
    'sales','sale_items','payments'
  ]
  loop
    execute format('alter table %I enable row level security;', t);
    execute format('drop policy if exists shop_isolation on %I;', t);
    execute format($f$
      create policy shop_isolation on %I
        for all
        to authenticated
        using (shop_id = auth_shop_id())
        with check (shop_id = auth_shop_id());
    $f$, t);
  end loop;
end $$;
