-- ======================================================
-- MIGRATION: pos/039-royalty-overhaul.sql
-- Overhauls the royalty (regalías) subsystem to match the new model:
--   * royalty_rule no longer locks to a single classification dimension
--     (drops royalty_rule.tenant_product_group_type_id). A rule can now
--     cover groups from any dimension via its options.
--   * royalty_option drops the scope column. variant.giftable = true is
--     the sole gating criterion. Specific-product targeting is removed,
--     so royalty_option_product is dropped entirely.
--   * Selecting a group on an option implicitly includes its descendants
--     in the tenant_product_group hierarchy (resolved via recursive CTE
--     at query time; no schema change required for that behaviour).
--   * sale_item gains royalty_option_id / royalty_rule_id for audit
--     traceability of gifted items, and 'ROYALTY' becomes a valid
--     sale_price_type.
--
-- Existing royalty data is intentionally wiped — per directive this
-- migration overwrites the prior model.
--
-- AUDIT: 2026-05-14
-- ======================================================
 BEGIN;

-- Drop dependent table (specific-product targeting)

DROP TABLE IF EXISTS pos_schema.royalty_option_product;

-- Drop scope column from royalty_option

ALTER TABLE pos_schema.royalty_option
DROP COLUMN IF EXISTS scope;

-- Drop dimension index + FK + column from royalty_rule

DROP INDEX IF EXISTS pos_schema.idx_royalty_rule_dimension;


ALTER TABLE pos_schema.royalty_rule
DROP CONSTRAINT IF EXISTS fk_royalty_rule_group_type;


ALTER TABLE pos_schema.royalty_rule
DROP COLUMN IF EXISTS tenant_product_group_type_id;

-- Royalty audit columns on sale_item

ALTER TABLE pos_schema.sale_item ADD COLUMN IF NOT EXISTS royalty_option_id UUID,
                                                                            ADD COLUMN IF NOT EXISTS royalty_rule_id UUID;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sale_item_royalty_option_id_fkey'
          AND conrelid = 'pos_schema.sale_item'::regclass
    ) THEN
        ALTER TABLE pos_schema.sale_item
            ADD CONSTRAINT sale_item_royalty_option_id_fkey
            FOREIGN KEY (royalty_option_id)
            REFERENCES pos_schema.royalty_option(royalty_option_id)
            ON DELETE SET NULL;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sale_item_royalty_rule_id_fkey'
          AND conrelid = 'pos_schema.sale_item'::regclass
    ) THEN
        ALTER TABLE pos_schema.sale_item
            ADD CONSTRAINT sale_item_royalty_rule_id_fkey
            FOREIGN KEY (royalty_rule_id)
            REFERENCES pos_schema.royalty_rule(royalty_rule_id)
            ON DELETE SET NULL;
    END IF;
END $$;

-- Allow 'ROYALTY' as a valid sale_price_type. The original CHECK
-- constraint is auto-named by Postgres; resolve it dynamically before
-- recreating to handle any naming suffix variance.
DO $$
DECLARE
    v_constraint TEXT;
BEGIN
    FOR v_constraint IN
        SELECT conname FROM pg_constraint
        WHERE conrelid = 'pos_schema.sale_item'::regclass
          AND contype = 'c'
          AND pg_get_constraintdef(oid) ILIKE '%sale_price_type%'
    LOOP
        EXECUTE format('ALTER TABLE pos_schema.sale_item DROP CONSTRAINT %I', v_constraint);
    END LOOP;
END $$;


ALTER TABLE pos_schema.sale_item ADD CONSTRAINT sale_item_sale_price_type_check CHECK (sale_price_type IN ('NORMAL',
                                                                                                           'PROMO',
                                                                                                           'SEGMENT',
                                                                                                           'MANUAL',
                                                                                                           'ROYALTY'));


CREATE INDEX IF NOT EXISTS idx_sale_item_royalty_option ON pos_schema.sale_item(royalty_option_id)
WHERE royalty_option_id IS NOT NULL;


CREATE INDEX IF NOT EXISTS idx_sale_item_royalty_rule ON pos_schema.sale_item(royalty_rule_id)
WHERE royalty_rule_id IS NOT NULL;


COMMIT;

-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- DROP INDEX IF EXISTS pos_schema.idx_sale_item_royalty_option;
-- DROP INDEX IF EXISTS pos_schema.idx_sale_item_royalty_rule;
-- ALTER TABLE pos_schema.sale_item DROP CONSTRAINT IF EXISTS sale_item_royalty_option_id_fkey;
-- ALTER TABLE pos_schema.sale_item DROP CONSTRAINT IF EXISTS sale_item_royalty_rule_id_fkey;
-- ALTER TABLE pos_schema.sale_item DROP COLUMN IF EXISTS royalty_option_id;
-- ALTER TABLE pos_schema.sale_item DROP COLUMN IF EXISTS royalty_rule_id;
-- ALTER TABLE pos_schema.sale_item DROP CONSTRAINT IF EXISTS sale_item_sale_price_type_check;
-- ALTER TABLE pos_schema.sale_item
--     ADD CONSTRAINT sale_item_sale_price_type_check
--     CHECK (sale_price_type IN ('NORMAL', 'PROMO', 'SEGMENT', 'MANUAL'));
-- ALTER TABLE pos_schema.royalty_rule ADD COLUMN tenant_product_group_type_id UUID;
-- ALTER TABLE pos_schema.royalty_rule
--     ADD CONSTRAINT fk_royalty_rule_group_type
--     FOREIGN KEY (tenant_id, tenant_product_group_type_id)
--     REFERENCES general_schema.tenant_product_group_type(tenant_id, tenant_product_group_type_id)
--     ON DELETE CASCADE;
-- CREATE INDEX idx_royalty_rule_dimension
--     ON pos_schema.royalty_rule(tenant_id, tenant_product_group_type_id, min_amount ASC);
-- ALTER TABLE pos_schema.royalty_option
--     ADD COLUMN scope TEXT NOT NULL DEFAULT 'any' CHECK (scope IN ('any','specific'));
-- CREATE TABLE pos_schema.royalty_option_product (
--     royalty_option_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--     royalty_option_id UUID NOT NULL REFERENCES pos_schema.royalty_option(royalty_option_id) ON DELETE CASCADE,
--     product_variant_id UUID NOT NULL,
--     UNIQUE (royalty_option_id, product_variant_id)
-- );
-- COMMIT;
