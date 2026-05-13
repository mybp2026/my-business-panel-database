-- ======================================================
-- MIGRATION: pos/032-einvoice-cron-replacement.sql
-- ======================================================
-- Author: David
-- Date: 2026-05-13
-- Description:
--   Replaces the BullMQ-based e-invoice status polling with a pure
--   cron-based reconciliation.
--
--   Self-contained: re-applies the column adds + status seed from
--   migration 011 with IF NOT EXISTS / ON CONFLICT, so it runs cleanly
--   on databases where 011 was never executed (e.g. environments built
--   from an older backup).
--
-- Dependencies: none (subsumes 011-einvoice-check-tracking.sql)
-- Breaking Changes: NO (additive + idempotent backfill)
-- ======================================================

BEGIN;

-- Columns (idempotent; from migration 011 originally).
ALTER TABLE pos_schema.electronic_sale_invoice
    ADD COLUMN IF NOT EXISTS check_attempts INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS next_check_at  TIMESTAMP;

-- status_id = 4 (timeout) used by the cron when MAX_ATTEMPTS exhausts.
INSERT INTO pos_schema.invoice_status (status_id, description)
VALUES (4, 'timeout')
ON CONFLICT (status_id) DO NOTHING;

-- Partial index for the cron query.
CREATE INDEX IF NOT EXISTS idx_electronic_invoice_pending_check
    ON pos_schema.electronic_sale_invoice (next_check_at)
    WHERE status_id = 1;

-- Backfill: schedule any pending invoice without next_check_at so the
-- new cron picks it up on the next tick.
UPDATE pos_schema.electronic_sale_invoice
SET next_check_at = NOW() + INTERVAL '15 minutes'
WHERE status_id = 1
  AND next_check_at IS NULL;

COMMIT;

-- ======================================================
-- ROLLBACK (manual):
-- ======================================================
-- BEGIN;
-- DROP INDEX IF EXISTS pos_schema.idx_electronic_invoice_pending_check;
-- DELETE FROM pos_schema.invoice_status WHERE status_id = 4;
-- ALTER TABLE pos_schema.electronic_sale_invoice
--     DROP COLUMN IF EXISTS check_attempts,
--     DROP COLUMN IF EXISTS next_check_at;
-- COMMIT;
