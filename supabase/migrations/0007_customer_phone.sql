-- Optional customer phone on sales (paired with customer_name). Used by the
-- credit book so a debtor can be contacted. Nullable; older rows stay valid.
alter table sales add column if not exists customer_phone text;
