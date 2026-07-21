-- Phase 9 — shop logo on the storefront.

alter table storefronts add column if not exists logo_url text;

-- Reuse the existing PUBLIC product-images bucket for shop logos too (same
-- read-everyone / write-authenticated policy already covers it — no new
-- bucket or policy needed).
