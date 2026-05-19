-- ============================================================================
-- MIGRATION: pos/041-sale-items-product-variant-set-null.sql
-- Date: 2026-05-19
-- Description: Change product_variant FK on POS item tables from RESTRICT to
--              SET NULL so that deleting a product_variant nullifies the
--              reference in historical records rather than blocking the delete.
--              Columns are made nullable to support SET NULL.
-- ============================================================================

BEGIN;

-- ─── sale_item ───────────────────────────────────────────────────────────────
ALTER TABLE pos_schema.sale_item
    ALTER COLUMN product_variant_id DROP NOT NULL;

ALTER TABLE pos_schema.sale_item
    DROP CONSTRAINT IF EXISTS sale_item_product_variant_fkey;
ALTER TABLE pos_schema.sale_item
    ADD CONSTRAINT sale_item_product_variant_fkey
    FOREIGN KEY (tenant_id, product_variant_id)
    REFERENCES general_schema.product_variant(tenant_id, product_variant_id)
    ON DELETE SET NULL;

-- ─── electronic_sale_invoice_items ───────────────────────────────────────────
ALTER TABLE pos_schema.electronic_sale_invoice_items
    ALTER COLUMN product_variant_id DROP NOT NULL;

ALTER TABLE pos_schema.electronic_sale_invoice_items
    DROP CONSTRAINT IF EXISTS fk_electronic_item_product_variant;
ALTER TABLE pos_schema.electronic_sale_invoice_items
    ADD CONSTRAINT fk_electronic_item_product_variant
    FOREIGN KEY (tenant_id, product_variant_id)
    REFERENCES general_schema.product_variant(tenant_id, product_variant_id)
    ON DELETE SET NULL;

-- ─── digital_sale_invoice_item ───────────────────────────────────────────────
ALTER TABLE pos_schema.digital_sale_invoice_item
    ALTER COLUMN product_variant_id DROP NOT NULL;

-- Constraint has no explicit name; resolve dynamically.
DO $$
DECLARE v_constraint_name TEXT;
BEGIN
    SELECT conname INTO v_constraint_name
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE n.nspname = 'pos_schema'
      AND t.relname = 'digital_sale_invoice_item'
      AND c.contype = 'f'
      AND EXISTS (
          SELECT 1 FROM pg_attribute a
          WHERE a.attrelid = t.oid AND a.attname = 'product_variant_id'
            AND a.attnum = ANY(c.conkey)
      );
    IF v_constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE pos_schema.digital_sale_invoice_item DROP CONSTRAINT '
                || quote_ident(v_constraint_name);
    END IF;
END $$;
ALTER TABLE pos_schema.digital_sale_invoice_item
    ADD CONSTRAINT digital_sale_invoice_item_product_variant_fkey
    FOREIGN KEY (tenant_id, product_variant_id)
    REFERENCES general_schema.product_variant(tenant_id, product_variant_id)
    ON DELETE SET NULL;

COMMIT;
