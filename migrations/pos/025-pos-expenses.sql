-- ======================================================
-- MIGRATION: pos/025-pos-expenses.sql
-- Adds operational expense tracking for POS branches.
-- expense_type: tenant-level catalog of common expense types.
-- expense:      per-branch expense records tied to a user.
-- ======================================================

BEGIN;

CREATE TABLE IF NOT EXISTS pos_schema.expense_type (
    expense_type_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           uuid NOT NULL,
    expense_type_name   VARCHAR(100) NOT NULL,
    expense_type_detail TEXT,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_expense_type_tenant
    ON pos_schema.expense_type(tenant_id);

CREATE TABLE IF NOT EXISTS pos_schema.expense (
    expense_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_type_id uuid NOT NULL REFERENCES pos_schema.expense_type(expense_type_id) ON DELETE RESTRICT,
    expense_amount  NUMERIC(14, 2) NOT NULL CHECK (expense_amount > 0),
    branch_id       uuid NOT NULL,
    user_id         uuid NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_expense_type_fk  ON pos_schema.expense(expense_type_id);
CREATE INDEX IF NOT EXISTS idx_expense_branch    ON pos_schema.expense(branch_id);
CREATE INDEX IF NOT EXISTS idx_expense_user      ON pos_schema.expense(user_id);

COMMIT;


-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- DROP TABLE IF EXISTS pos_schema.expense CASCADE;
-- DROP TABLE IF EXISTS pos_schema.expense_type CASCADE;
-- COMMIT;
