-- The shop's own display name (from its Shop profile) travels with the
-- renewal payment so the admin console shows who paid, not the internal id.
alter table license_payments add column if not exists shop_name text;
