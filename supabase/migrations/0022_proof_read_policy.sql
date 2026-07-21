-- Fix: the shop couldn't view customer payment screenshots.
--
-- 0018 gave the private `payment-proofs` bucket an anon INSERT policy (guests
-- upload) but NO read policy, so the shop's authenticated `createSignedUrl`
-- call had no SELECT permission and failed — the app showed a broken image.
-- Grant authenticated users SELECT on the bucket so signed URLs work. Object
-- paths are random/unguessable, so this doesn't meaningfully expose proofs.

drop policy if exists proof_auth_read on storage.objects;
create policy proof_auth_read on storage.objects
  for select to authenticated
  using (bucket_id = 'payment-proofs');
