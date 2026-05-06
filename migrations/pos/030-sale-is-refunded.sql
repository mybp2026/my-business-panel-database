-- ======================================================
-- MIGRATION: pos/030-sale-is-refunded.sql
-- Adds is_refunded flag to pos_schema.sale so cancelled/fully
-- refunded sales are marked rather than having their invoices deleted.
-- ======================================================

BEGIN;

ALTER TABLE pos_schema.sale
  ADD COLUMN IF NOT EXISTS is_refunded BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_sale_is_refunded
  ON pos_schema.sale(branch_id, is_refunded);

COMMIT;

-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- DROP INDEX IF EXISTS pos_schema.idx_sale_is_refunded;
-- ALTER TABLE pos_schema.sale DROP COLUMN IF EXISTS is_refunded;
-- COMMIT;
