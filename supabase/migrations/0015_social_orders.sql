-- Phase 7 — Social Order Kanban.
--
-- Orders that arrive via social channels (Facebook/Viber/TikTok/phone) are
-- tracked through a Kanban pipeline (new → confirmed → packed → shipped →
-- delivered, plus cancelled) BEFORE they become an in-store sale. Unlike
-- `sales` (append-only), an order is mutable: its status moves across the board
-- and its items get edited, so it syncs last-write-wins on `updated_at`.
--
-- Stock is NOT touched at the order stage. When an order is delivered it is
-- converted into a `sales` row (+ stock movements) by the app's SalesRepository
-- — the single place that owns the append-only ledger. `orders.sale_id` links
-- back to that sale.

create table if not exists orders (
  id               text primary key,
  shop_id          text not null,
  order_no         text not null,
  channel          text not null default 'facebook',
  status           text not null default 'new',
  customer_name    text not null,
  customer_phone   text,
  delivery_address text,
  delivery_fee     integer not null default 0,
  items_total      integer not null default 0,
  payment_status   text not null default 'unpaid',
  note             text,
  sale_id          text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  is_deleted       boolean not null default false
);
create index if not exists idx_orders_shop_updated
  on orders (shop_id, updated_at);
create index if not exists idx_orders_shop_status
  on orders (shop_id, status) where is_deleted = false;

alter table orders enable row level security;
drop policy if exists shop_isolation on orders;
create policy shop_isolation on orders
  for all to authenticated
  using (shop_id = auth_shop_id()) with check (shop_id = auth_shop_id());

create table if not exists order_items (
  id             text primary key,
  shop_id        text not null,
  order_id       text not null,
  product_id     text,
  name_snapshot  text not null,
  price_snapshot integer not null,
  qty            integer not null,
  line_total     integer not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  is_deleted     boolean not null default false
);
create index if not exists idx_order_items_shop_updated
  on order_items (shop_id, updated_at);
create index if not exists idx_order_items_order
  on order_items (order_id) where is_deleted = false;

alter table order_items enable row level security;
drop policy if exists shop_isolation on order_items;
create policy shop_isolation on order_items
  for all to authenticated
  using (shop_id = auth_shop_id()) with check (shop_id = auth_shop_id());
