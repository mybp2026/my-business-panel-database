-- MGP1: Add nullable supplier FK to product_variant
-- Allows associating a supplier with any product variant (simple or composite)

ALTER TABLE general_schema.product_variant
    ADD COLUMN IF NOT EXISTS supplier_id UUID
        REFERENCES purchase_schema.supplier(supplier_id)
        ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_product_variant_supplier
    ON general_schema.product_variant(supplier_id)
    WHERE supplier_id IS NOT NULL;
