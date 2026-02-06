-- ======================================================
-- MIGRATION: purchase_schema/001-supplier-added-by-branch.sql
-- ======================================================
-- Author: David
-- Description: Adds `added_by` column to supplier table.
--              This UUID references general_schema.branch(branch_id),
--              allowing each supplier to be scoped to the branch that created it.
-- 
-- Dependencies: purchase_schema.sql, general_schema.sql must exist
-- Breaking Changes: NO - Adds nullable column first, then can be made NOT NULL after backfill
-- Rollback: See bottom of file
-- ======================================================

BEGIN;

SET SEARCH_PATH TO purchase_schema;

ALTER TABLE purchase_schema.supplier
ADD COLUMN IF NOT EXISTS added_by uuid
    REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_supplier_added_by
    ON purchase_schema.supplier(added_by)
    WHERE added_by IS NOT NULL;

COMMIT;

-- ======================================================
-- ROLLBACK (run manually if needed):
-- ======================================================
-- BEGIN;
-- DROP INDEX IF EXISTS purchase_schema.idx_supplier_added_by;
-- ALTER TABLE purchase_schema.supplier DROP COLUMN IF EXISTS added_by;
-- COMMIT;
