-- ======================================================
-- MIGRATION: pos/016-promotion-targeting.sql
-- Adds promotion targeting: a promotion can apply to a
-- specific product_variant OR to a tenant_product_group
-- (and its descendants). Mutually exclusive via CHECK.
-- Depends on migration general/027 for the
-- tenant_product_group table.
-- ======================================================

BEGIN;

CREATE TABLE IF NOT EXISTS pos_schema.promotion_target (
    promotion_target_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id               uuid NOT NULL REFERENCES pos_schema.promotion(promotion_id) ON DELETE CASCADE,
    tenant_id                  uuid NOT NULL,
    target_type                VARCHAR(20) NOT NULL CHECK (target_type IN ('VARIANT','GROUP')),
    target_product_variant_id  uuid,
    target_group_id            uuid,
    created_at                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (
      (target_type = 'VARIANT' AND target_product_variant_id IS NOT NULL AND target_group_id IS NULL) OR
      (target_type = 'GROUP'   AND target_group_id IS NOT NULL AND target_product_variant_id IS NULL)
    ),
    FOREIGN KEY (tenant_id, target_product_variant_id)
        REFERENCES general_schema.product_variant(tenant_id, product_variant_id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, target_group_id)
        REFERENCES general_schema.tenant_product_group(tenant_id, tenant_product_group_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_promo_target_promo
    ON pos_schema.promotion_target(promotion_id);
CREATE INDEX IF NOT EXISTS idx_promo_target_variant
    ON pos_schema.promotion_target(tenant_id, target_product_variant_id) WHERE target_product_variant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_promo_target_group
    ON pos_schema.promotion_target(tenant_id, target_group_id) WHERE target_group_id IS NOT NULL;

COMMIT;


-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- DROP TABLE IF EXISTS pos_schema.promotion_target CASCADE;
-- COMMIT;
