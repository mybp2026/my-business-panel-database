-- ============================================================================
-- Migration 015: Add electronic invoice support to return_transaction
-- ============================================================================
-- Adds electronic_sale_invoice_id column and makes digital_sale_invoice_id
-- nullable, with a CHECK constraint requiring at least one to be set.
-- This enables refunds against either digital or electronic invoices.
-- ============================================================================

BEGIN;

-- Drop existing NOT NULL on digital_sale_invoice_id
ALTER TABLE pos_schema.return_transaction
    ALTER COLUMN digital_sale_invoice_id DROP NOT NULL;

-- Add electronic_sale_invoice_id FK (nullable)
ALTER TABLE pos_schema.return_transaction
    ADD COLUMN IF NOT EXISTS electronic_sale_invoice_id uuid
        REFERENCES pos_schema.electronic_sale_invoice(electronic_sale_invoice_id)
        ON DELETE CASCADE;

-- Require at least one invoice reference
ALTER TABLE pos_schema.return_transaction
    DROP CONSTRAINT IF EXISTS chk_return_transaction_invoice;
ALTER TABLE pos_schema.return_transaction
    ADD CONSTRAINT chk_return_transaction_invoice CHECK (
        digital_sale_invoice_id IS NOT NULL
        OR electronic_sale_invoice_id IS NOT NULL
    );

CREATE INDEX IF NOT EXISTS idx_return_transaction_electronic_sale_invoice_id
    ON pos_schema.return_transaction(electronic_sale_invoice_id);

-- ────────────────────────────────────────────────────────────────────────────
-- Add ON DELETE CASCADE to electronic_sale_invoice_items.sale_item_id so the
-- update_on_return trigger (which deletes sale_item rows when their quantity
-- reaches 0) doesn't fail when the sale has an electronic invoice attached.
-- ────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    fk_name text;
BEGIN
    SELECT conname INTO fk_name
    FROM pg_constraint
    WHERE conrelid = 'pos_schema.electronic_sale_invoice_items'::regclass
      AND contype = 'f'
      AND pg_get_constraintdef(oid) LIKE '%REFERENCES pos_schema.sale_item(sale_item_id)%';

    IF fk_name IS NOT NULL THEN
        EXECUTE format(
            'ALTER TABLE pos_schema.electronic_sale_invoice_items DROP CONSTRAINT %I',
            fk_name
        );
    END IF;

    ALTER TABLE pos_schema.electronic_sale_invoice_items
        ADD CONSTRAINT electronic_sale_invoice_items_sale_item_id_fkey
        FOREIGN KEY (sale_item_id)
        REFERENCES pos_schema.sale_item(sale_item_id)
        ON DELETE CASCADE;
END $$;

COMMIT;

-- ────────────────────────────────────────────────────────────────────────────
-- Rollback (manual):
-- ALTER TABLE pos_schema.return_transaction DROP CONSTRAINT chk_return_transaction_invoice;
-- DROP INDEX IF EXISTS pos_schema.idx_return_transaction_electronic_sale_invoice_id;
-- ALTER TABLE pos_schema.return_transaction DROP COLUMN IF EXISTS electronic_sale_invoice_id;
-- UPDATE pos_schema.return_transaction SET digital_sale_invoice_id = '<placeholder>' WHERE digital_sale_invoice_id IS NULL;
-- ALTER TABLE pos_schema.return_transaction ALTER COLUMN digital_sale_invoice_id SET NOT NULL;
-- ────────────────────────────────────────────────────────────────────────────
