-- ======================================================
-- MIGRATION: general/022-move-econ-activity-to-tenant.sql
-- Moves econ_activity ownership exclusively to tenant.
-- - Sets econ_activity on the target tenant.
-- - Drops the econ_activity column from branch.
-- ======================================================

BEGIN;

-- 1. Set the correct economic activity code on the tenant
UPDATE general_schema.tenant
SET econ_activity = '6201.0'
WHERE tenant_id = '3e668234-c171-440d-9b14-c47908ec1bb3';

-- 2. Drop econ_activity from branch (it now lives exclusively on tenant)
ALTER TABLE general_schema.branch DROP COLUMN IF EXISTS econ_activity;

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- ALTER TABLE general_schema.branch ADD COLUMN IF NOT EXISTS econ_activity VARCHAR(10);
-- UPDATE general_schema.tenant SET econ_activity = NULL WHERE tenant_id = '3e668234-c171-440d-9b14-c47908ec1bb3';
-- COMMIT;
