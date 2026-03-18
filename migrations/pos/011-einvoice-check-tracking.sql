-- ======================================================
-- MIGRATION: pos/011-einvoice-check-tracking.sql
-- ======================================================
-- Author: David
-- Date: 2026-03-12
-- Description: Adds async status-tracking columns to electronic_sale_invoice
--   to support the Opción C strategy (cron with exponential backoff):
--
--   1. check_attempts INT — how many times Hacienda has been polled
--   2. next_check_at  TIMESTAMP — when to run the next poll (backoff schedule)
--   3. Status 4 = 'timeout' — for invoices that never resolve after 20 attempts
--   4. Partial index on (status_id, next_check_at) for efficient cron query
--
-- Dependencies: 010-branch-einvoice-sequence.sql
-- Breaking Changes: NO (additive only)
-- Rollback: See bottom of file
-- ======================================================

BEGIN;

ALTER TABLE pos_schema.electronic_sale_invoice
    ADD COLUMN IF NOT EXISTS check_attempts INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS next_check_at  TIMESTAMP;

COMMENT ON COLUMN pos_schema.electronic_sale_invoice.check_attempts IS
    'Number of Hacienda status polls performed so far. Capped at 20 before marking timeout.';
COMMENT ON COLUMN pos_schema.electronic_sale_invoice.next_check_at IS
    'Scheduled time for the next status poll. NULL means already resolved or not yet set.';

-- Backfill: existing pending invoices get next_check_at = NOW() so the cron
-- picks them up on its very first tick.
UPDATE pos_schema.electronic_sale_invoice
SET next_check_at = NOW()
WHERE status_id = 1
  AND next_check_at IS NULL;

-- Add timeout status (4) if it does not already exist
INSERT INTO pos_schema.invoice_status (status_id, description)
VALUES (4, 'timeout')
ON CONFLICT (status_id) DO NOTHING;

-- Partial index: only indexes pending rows, keeping it small and fast for the cron query
CREATE INDEX IF NOT EXISTS idx_electronic_invoice_pending_check
    ON pos_schema.electronic_sale_invoice (next_check_at)
    WHERE status_id = 1;

COMMIT;

-- ======================================================
-- ROLLBACK (run manually if needed):
-- ======================================================
-- BEGIN;
-- DROP INDEX IF EXISTS pos_schema.idx_electronic_invoice_pending_check;
-- DELETE FROM pos_schema.invoice_status WHERE status_id = 4;
-- ALTER TABLE pos_schema.electronic_sale_invoice
--     DROP COLUMN IF EXISTS check_attempts,
--     DROP COLUMN IF EXISTS next_check_at;
-- COMMIT;
