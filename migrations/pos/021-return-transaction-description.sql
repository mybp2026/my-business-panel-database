-- Migration: 021-return-transaction-description
-- Adds required description field to return_transaction for refund justification.
-- Idempotent: uses IF NOT EXISTS column check.
--
-- ROLLBACK (comment out before applying):
-- ALTER TABLE pos_schema.return_transaction DROP COLUMN IF EXISTS description;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'pos_schema'
          AND table_name   = 'return_transaction'
          AND column_name  = 'description'
    ) THEN
        ALTER TABLE pos_schema.return_transaction
            ADD COLUMN description TEXT NOT NULL DEFAULT 'Sin descripción';

        -- Remove the temporary default so future inserts must supply a value
        ALTER TABLE pos_schema.return_transaction
            ALTER COLUMN description DROP DEFAULT;
    END IF;
END $$;
