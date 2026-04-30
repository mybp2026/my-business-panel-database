-- ============================================================
-- Migration general-028: ensure product_variant.cost_price
-- ------------------------------------------------------------
--   Cost tracking columns were added in 013-add-cost-tracking,
--   but the product create/update API path did not expose
--   cost_price until now. This migration is idempotent: it
--   guarantees the column exists in environments that may have
--   diverged, and re-asserts the default + check constraint.
-- ============================================================

BEGIN;

ALTER TABLE general_schema.product_variant
    ADD COLUMN IF NOT EXISTS cost_price NUMERIC(12,3) DEFAULT 0;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'product_variant_cost_price_check'
          AND conrelid = 'general_schema.product_variant'::regclass
    ) THEN
        ALTER TABLE general_schema.product_variant
            ADD CONSTRAINT product_variant_cost_price_check
            CHECK (cost_price IS NULL OR cost_price >= 0);
    END IF;
END $$;

UPDATE general_schema.product_variant
SET cost_price = 0
WHERE cost_price IS NULL;

COMMIT;
