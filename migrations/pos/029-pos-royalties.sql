-- ======================================================
-- MIGRATION: pos/029-pos-royalties.sql
-- Creates royalty (regalías) configuration tables for wholesale clients.
-- A royalty_rule defines a minimum purchase amount threshold.
-- Each rule has N options (one per product group/department).
-- Each option can include any giftable product from the group or specific ones.
-- ======================================================

BEGIN;

CREATE TABLE IF NOT EXISTS pos_schema.royalty_rule (
    royalty_rule_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID NOT NULL REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE,
    min_amount        NUMERIC(14,2) NOT NULL CHECK (min_amount > 0),
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_royalty_rule_tenant
    ON pos_schema.royalty_rule(tenant_id, min_amount ASC);

-- Each option belongs to one rule and targets one product group.
-- tenant_id duplicated here to satisfy the composite FK on tenant_product_group(tenant_id, tenant_product_group_id).
-- scope: 'any' = any giftable product from group, 'specific' = predefined list.
CREATE TABLE IF NOT EXISTS pos_schema.royalty_option (
    royalty_option_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    royalty_rule_id           UUID NOT NULL REFERENCES pos_schema.royalty_rule(royalty_rule_id) ON DELETE CASCADE,
    tenant_id                 UUID NOT NULL,
    tenant_product_group_id   UUID NOT NULL,
    quantity                  INT NOT NULL CHECK (quantity > 0),
    scope                     TEXT NOT NULL DEFAULT 'any' CHECK (scope IN ('any', 'specific')),
    created_at                TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (royalty_rule_id, tenant_product_group_id),
    FOREIGN KEY (tenant_id, tenant_product_group_id)
        REFERENCES general_schema.tenant_product_group(tenant_id, tenant_product_group_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_royalty_option_rule
    ON pos_schema.royalty_option(royalty_rule_id);

-- Specific product variants assigned to an option (only when scope = 'specific').
-- No FK on product_variant_id because product_variant uses a hash-partitioned composite PK.
CREATE TABLE IF NOT EXISTS pos_schema.royalty_option_product (
    royalty_option_product_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    royalty_option_id           UUID NOT NULL REFERENCES pos_schema.royalty_option(royalty_option_id) ON DELETE CASCADE,
    product_variant_id          UUID NOT NULL,
    UNIQUE (royalty_option_id, product_variant_id)
);

CREATE INDEX IF NOT EXISTS idx_royalty_option_product_option
    ON pos_schema.royalty_option_product(royalty_option_id);

COMMIT;

-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- DROP TABLE IF EXISTS pos_schema.royalty_option_product;
-- DROP TABLE IF EXISTS pos_schema.royalty_option;
-- DROP TABLE IF EXISTS pos_schema.royalty_rule;
-- COMMIT;
