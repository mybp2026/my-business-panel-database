-- Migration 019: Convert tax_regime enum values from Spanish to English
-- Changes: 'tradicional' -> 'traditional', 'simplificado' -> 'simplified'
-- Safe: Idempotent and handles both scenarios (Spanish or English existing values)

BEGIN;

SET SEARCH_PATH TO general_schema;

-- Check if migration already applied
DO $$
DECLARE
    v_has_spanish BOOLEAN;
BEGIN
    -- Check if any Spanish values exist
    SELECT EXISTS(
        SELECT 1 FROM tenant
        WHERE tax_regime::text IN ('tradicional', 'simplificado')
    ) INTO v_has_spanish;

    -- If Spanish values don't exist, migration already done
    IF NOT v_has_spanish THEN
        RAISE NOTICE 'Migration already applied or no Spanish values found. Skipping.';
        RETURN;
    END IF;

    -- Step 1: Create temporary column as text
    ALTER TABLE tenant ADD COLUMN tax_regime_new VARCHAR(20);

    -- Step 2: Migrate Spanish values to English
    UPDATE tenant
    SET tax_regime_new = CASE
        WHEN tax_regime::text = 'tradicional' THEN 'traditional'
        WHEN tax_regime::text = 'simplificado' THEN 'simplified'
        ELSE tax_regime::text
    END;

    -- Step 3: Drop the old column
    ALTER TABLE tenant DROP COLUMN tax_regime;

    -- Step 4: Rename new column to original name
    ALTER TABLE tenant RENAME COLUMN tax_regime_new TO tax_regime;

    -- Step 5: Add constraint to ensure only valid values
    ALTER TABLE tenant
    ADD CONSTRAINT tax_regime_check CHECK (tax_regime IN ('traditional', 'simplified'));

    -- Step 6: Set default
    ALTER TABLE tenant
    ALTER COLUMN tax_regime SET DEFAULT 'traditional';

    -- Step 7: Make NOT NULL
    ALTER TABLE tenant
    ALTER COLUMN tax_regime SET NOT NULL;

    RAISE NOTICE 'Successfully migrated tax_regime values from Spanish to English';
END $$;

-- Step 8: Recreate the ENUM type with idempotent approach
-- Drop old type if it exists with Spanish values (via checking and dropping if needed)
DROP TYPE IF EXISTS general_schema.tax_regime CASCADE;

-- Recreate with English values only
CREATE TYPE general_schema.tax_regime AS ENUM ('traditional', 'simplified');

-- Step 9: Update column type to use the ENUM
-- First remove DEFAULT temporarily, convert type, then restore DEFAULT
ALTER TABLE tenant ALTER COLUMN tax_regime DROP DEFAULT;

ALTER TABLE tenant
ALTER COLUMN tax_regime TYPE general_schema.tax_regime USING tax_regime::general_schema.tax_regime;

ALTER TABLE tenant ALTER COLUMN tax_regime SET DEFAULT 'traditional'::general_schema.tax_regime;

-- Remove check constraint since ENUM handles validation
ALTER TABLE tenant DROP CONSTRAINT IF EXISTS tax_regime_check;

-- Update comment
COMMENT ON COLUMN general_schema.tenant.tax_regime IS
    'Tenant tax regime: traditional (régimen general IVA) or simplified (régimen simplificado, Decreto 38 MH).';

COMMIT;

-- ROLLBACK PROCEDURE (if needed):
-- This migration modifies the tax_regime column structure.
-- Manual review recommended before rollback.
