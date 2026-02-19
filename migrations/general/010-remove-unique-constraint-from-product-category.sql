-- ============================================================================
-- MIGRATION: 010-remove-unique-constraint-from-product-category.sql
-- ============================================================================
-- Author: David
-- Date: 2026-02-18
-- Description: Removes the unique constraint from the category_name column in the
--              product_category table.
--
-- Changes:
--   1. Removes the unique constraint on general_schema.product_category.category_name
--
-- Dependencies: None
-- Breaking Changes: NO
-- Rollback: See bottom of file
-- ============================================================================

BEGIN;

SET SEARCH_PATH TO general_schema;

-- ============================================================================
-- STEP 1: Remove unique constraint from category_name in product_category
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE table_schema = 'general_schema'
          AND table_name = 'product_category'
          AND constraint_type = 'UNIQUE'
          AND constraint_name = 'product_category_category_name_key'
    ) THEN
        ALTER TABLE general_schema.product_category
            DROP CONSTRAINT product_category_category_name_key;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================================
-- ROLLBACK (Run manually if needed)
-- ============================================================================
/*
BEGIN;

SET SEARCH_PATH TO general_schema;

ALTER TABLE general_schema.product_category
    ADD CONSTRAINT IF NOT EXISTS product_category_category_name_key UNIQUE (category_name);

COMMIT;
*/