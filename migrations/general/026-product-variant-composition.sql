-- ======================================================
-- MIGRATION: general/026-product-variant-composition.sql
-- Adds support for composite product variants (e.g., a
-- six-pack that "explodes" into 6 individual bottles, or
-- a clothing batch that explodes into individual shirts).
-- The composite itself is virtual: it has no row in
-- inventory; stock is computed from its components.
-- ======================================================

BEGIN;

CREATE TABLE IF NOT EXISTS general_schema.product_variant_composition (
    tenant_id                  uuid    NOT NULL,
    parent_product_variant_id  uuid    NOT NULL,
    child_product_variant_id   uuid    NOT NULL,
    quantity                   numeric(12,3) NOT NULL CHECK (quantity > 0),
    created_at                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, parent_product_variant_id, child_product_variant_id),
    CHECK (parent_product_variant_id <> child_product_variant_id),
    FOREIGN KEY (tenant_id, parent_product_variant_id)
        REFERENCES general_schema.product_variant(tenant_id, product_variant_id)
        ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, child_product_variant_id)
        REFERENCES general_schema.product_variant(tenant_id, product_variant_id)
        ON DELETE RESTRICT
) PARTITION BY HASH (tenant_id);

-- 8 partitions matching product_variant
DO $$ DECLARE i INT; BEGIN
  FOR i IN 0..7 LOOP
    EXECUTE format(
      'CREATE TABLE IF NOT EXISTS general_schema.product_variant_composition_p%s
       PARTITION OF general_schema.product_variant_composition
       FOR VALUES WITH (MODULUS 8, REMAINDER %s);', i, i);
  END LOOP;
END $$ LANGUAGE plpgsql;

CREATE INDEX IF NOT EXISTS idx_pvc_parent
    ON general_schema.product_variant_composition (tenant_id, parent_product_variant_id);
CREATE INDEX IF NOT EXISTS idx_pvc_child
    ON general_schema.product_variant_composition (tenant_id, child_product_variant_id);

ALTER TABLE general_schema.product_variant
    ADD COLUMN IF NOT EXISTS is_composite BOOLEAN NOT NULL DEFAULT false;

COMMENT ON TABLE general_schema.product_variant_composition IS
    'Composite product variants: a parent variant explodes into N children with a quantity ratio.
     - Parent is virtual: no inventory row, no direct stock movements.
     - On purchase reception: parent qty * child qty is added to each child inventory.
     - On sale: same explosion is applied to decrement child stock.
     - ON DELETE RESTRICT for child prevents silent breakage of compositions.';

COMMIT;


-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
--
-- ALTER TABLE general_schema.product_variant
--     DROP COLUMN IF EXISTS is_composite;
--
-- DROP TABLE IF EXISTS general_schema.product_variant_composition CASCADE;
--
-- COMMIT;
