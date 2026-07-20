-- Phase 9 — customer payment screenshots for storefront orders.
--
-- A guest uploads a KBZPay/WavePay transfer screenshot at checkout. The file
-- goes to a PRIVATE storage bucket; the shop views it later via a short-lived
-- signed URL. The order carries the file's storage path.

alter table orders add column if not exists payment_proof_path text;

-- Private bucket (no public read — proofs can contain sensitive info).
insert into storage.buckets (id, name, public)
values ('payment-proofs', 'payment-proofs', false)
on conflict (id) do nothing;

-- Anonymous guests may UPLOAD a proof, but never list/read the bucket. Reads
-- happen through signed URLs the shop's authenticated app requests.
drop policy if exists proof_anon_upload on storage.objects;
create policy proof_anon_upload on storage.objects
  for insert to anon
  with check (bucket_id = 'payment-proofs');
