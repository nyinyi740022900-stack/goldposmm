-- Phase 8 — carrier-agnostic delivery tracking groundwork.
--
-- No real carrier API is wired up yet (Ninja Van requires a manual sandbox
-- application + audit; Royal Express has no public developer API — see
-- PROJECT_SPEC §12). These columns let a shop record delivery info today
-- (township for routing, a manually-entered tracking number from the
-- carrier's own app/site, and a delivery-specific status) so the workflow
-- doesn't block on a real integration, and gives that future integration a
-- schema to land on.

alter table orders add column if not exists township text;
alter table orders add column if not exists delivery_carrier text;
alter table orders add column if not exists tracking_number text;
alter table orders add column if not exists delivery_status text;
