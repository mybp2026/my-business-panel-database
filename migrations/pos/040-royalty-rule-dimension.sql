-- ======================================================
-- MIGRATION: pos/040-royalty-rule-dimension.sql
-- Adds royalty_rule_dimension: the explicit list of classification
-- dimensions (tenant_product_group_type) that each royalty_rule applies
-- to. Without this, "no options of dimension X" is ambiguous (could mean
-- "not configured yet" or "intentionally excluded"). With this table the
-- editor knows exactly which dimensions the user opted into per rule.
--
-- Selection model:
--   * A rule has 0..N dimensions; each dimension may have 0..N options
--     (groups). Options remain in royalty_option.
--   * Removing a dimension cascades-deletes the options whose group
--     belongs to that dimension (handled at application layer).
--
-- AUDIT: 2026-05-14
-- ======================================================

BEGIN;

CREATE TABLE IF NOT EXISTS pos_schema.royalty_rule_dimension (
    royalty_rule_id              UUID NOT NULL
        REFERENCES pos_schema.royalty_rule(royalty_rule_id) ON DELETE CASCADE,
    tenant_id                    UUID NOT NULL,
    tenant_product_group_type_id UUID NOT NULL,
    created_at                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (royalty_rule_id, tenant_product_group_type_id),
    CONSTRAINT fk_royalty_rule_dim_type
        FOREIGN KEY (tenant_id, tenant_product_group_type_id)
        REFERENCES general_schema.tenant_product_group_type(tenant_id, tenant_product_group_type_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_royalty_rule_dimension_rule
    ON pos_schema.royalty_rule_dimension(royalty_rule_id);

CREATE INDEX IF NOT EXISTS idx_royalty_rule_dimension_type
    ON pos_schema.royalty_rule_dimension(tenant_id, tenant_product_group_type_id);

-- Backfill: seed dimensions for existing rules from the types of their
-- already-assigned option groups. Without this, pre-existing options
-- would be invisible to the new dimension-gated editor.
INSERT INTO pos_schema.royalty_rule_dimension (royalty_rule_id, tenant_id, tenant_product_group_type_id)
SELECT DISTINCT o.royalty_rule_id, o.tenant_id, g.tenant_product_group_type_id
FROM pos_schema.royalty_option o
INNER JOIN general_schema.tenant_product_group g
    ON g.tenant_id = o.tenant_id
   AND g.tenant_product_group_id = o.tenant_product_group_id
ON CONFLICT (royalty_rule_id, tenant_product_group_type_id) DO NOTHING;

COMMIT;

-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- DROP INDEX IF EXISTS pos_schema.idx_royalty_rule_dimension_type;
-- DROP INDEX IF EXISTS pos_schema.idx_royalty_rule_dimension_rule;
-- DROP TABLE IF EXISTS pos_schema.royalty_rule_dimension;
-- COMMIT;
