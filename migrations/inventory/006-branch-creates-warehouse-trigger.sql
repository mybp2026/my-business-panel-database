-- ======================================================
-- MIGRATION: inventory/006-branch-creates-warehouse-trigger.sql
-- ======================================================
-- Description: When a new branch is created (general_schema.branch),
--              automatically provision its sales-floor warehouse
--              (inventory_schema.warehouse with is_branch = TRUE).
--
-- Business Logic:
--   - Sales floor (is_branch = TRUE) is the inventory location used by POS.
--   - Each branch must have exactly one sales floor warehouse, enforced by
--     uq_warehouse_branch_sales_floor (created in migration 003).
--   - Default warehouse_name = branch_name, warehouse_address =
--     COALESCE(branch_address, '').
--   - Backfills any existing branches that don't have a sales floor yet.
-- ======================================================

BEGIN;

CREATE OR REPLACE FUNCTION inventory_schema.fn_branch_create_warehouse()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO inventory_schema.warehouse(
        branch_id,
        warehouse_name,
        warehouse_address,
        is_branch
    )
    VALUES (
        NEW.branch_id,
        NEW.branch_name,
        COALESCE(NEW.branch_address, ''),
        TRUE
    )
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_branch_create_warehouse ON general_schema.branch;

CREATE TRIGGER trg_branch_create_warehouse
AFTER INSERT ON general_schema.branch
FOR EACH ROW
EXECUTE FUNCTION inventory_schema.fn_branch_create_warehouse();

-- ------------------------------------------------------
-- Backfill: provision sales-floor warehouses for branches
-- that were created before this trigger existed.
-- ------------------------------------------------------
INSERT INTO inventory_schema.warehouse(
    branch_id,
    warehouse_name,
    warehouse_address,
    is_branch
)
SELECT
    b.branch_id,
    b.branch_name,
    COALESCE(b.branch_address, ''),
    TRUE
FROM general_schema.branch b
WHERE NOT EXISTS (
    SELECT 1
    FROM inventory_schema.warehouse w
    WHERE w.branch_id = b.branch_id
      AND w.is_branch = TRUE
);

COMMIT;

-- -----------------
-- ROLLBACK
-- -----------------
/*
BEGIN;

DROP TRIGGER IF EXISTS trg_branch_create_warehouse ON general_schema.branch;
DROP FUNCTION IF EXISTS inventory_schema.fn_branch_create_warehouse();

COMMIT;
*/
