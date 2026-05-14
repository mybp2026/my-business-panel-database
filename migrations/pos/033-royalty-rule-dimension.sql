-- ======================================================
-- MIGRATION: pos/033-royalty-rule-dimension.sql
-- Adds tenant_product_group_type_id (dimension) FK to
-- royalty_rule so each dimension can have its own
-- independent set of royalty rules.
-- Column is nullable to preserve existing rows.
-- New rules are required to supply a dimension at the
-- application layer.
-- FK is composite (tenant_id, tenant_product_group_type_id)
-- because tenant_product_group_type uses a composite PK.
-- ======================================================

BEGIN;

ALTER TABLE pos_schema.royalty_rule
    ADD COLUMN IF NOT EXISTS tenant_product_group_type_id UUID;

ALTER TABLE pos_schema.royalty_rule
    DROP CONSTRAINT IF EXISTS fk_royalty_rule_group_type;

ALTER TABLE pos_schema.royalty_rule
    ADD CONSTRAINT fk_royalty_rule_group_type
        FOREIGN KEY (tenant_id, tenant_product_group_type_id)
        REFERENCES general_schema.tenant_product_group_type(tenant_id, tenant_product_group_type_id)
        ON DELETE CASCADE;

DROP INDEX IF EXISTS pos_schema.idx_royalty_rule_tenant;

CREATE INDEX IF NOT EXISTS idx_royalty_rule_tenant
    ON pos_schema.royalty_rule(tenant_id, min_amount ASC);

CREATE INDEX IF NOT EXISTS idx_royalty_rule_dimension
    ON pos_schema.royalty_rule(tenant_id, tenant_product_group_type_id, min_amount ASC);

COMMIT;

-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- DROP INDEX IF EXISTS pos_schema.idx_royalty_rule_dimension;
-- ALTER TABLE pos_schema.royalty_rule
--     DROP CONSTRAINT IF EXISTS fk_royalty_rule_group_type;
-- ALTER TABLE pos_schema.royalty_rule
--     DROP COLUMN IF EXISTS tenant_product_group_type_id;
-- COMMIT;
