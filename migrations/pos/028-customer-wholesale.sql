-- ======================================================
-- MIGRATION: pos/028-customer-wholesale.sql
-- Adds is_wholesale flag to tenant_customer for royalty eligibility.
-- ======================================================

BEGIN;

ALTER TABLE general_schema.tenant_customer
ADD COLUMN IF NOT EXISTS is_wholesale BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_tenant_customer_wholesale
    ON general_schema.tenant_customer(tenant_id, is_wholesale);

COMMIT;

-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- DROP INDEX IF EXISTS general_schema.idx_tenant_customer_wholesale;
-- ALTER TABLE general_schema.tenant_customer DROP COLUMN IF EXISTS is_wholesale;
-- COMMIT;
