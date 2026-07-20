-- Phase 9 — product photos for the web storefront.
--
-- A public URL to the product's photo. Images live in a PUBLIC storage bucket
-- (catalog photos are meant to be seen by anyone browsing the storefront); the
-- shop owner (authenticated) uploads, everyone reads.

alter table products add column if not exists image_url text;

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

-- Public read for the bucket; only the shop's authenticated users may write.
drop policy if exists product_images_read on storage.objects;
create policy product_images_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'product-images');

drop policy if exists product_images_write on storage.objects;
create policy product_images_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'product-images');

drop policy if exists product_images_update on storage.objects;
create policy product_images_update on storage.objects
  for update to authenticated
  using (bucket_id = 'product-images');
