-- ======================================================
-- MIGRATION: pos/027-expense-status-workflow.sql
-- Adds status tracking and approval workflow to POS expenses.
-- Allows employees to request expenses and admins to approve/reject.
-- ======================================================

BEGIN;

-- Add status column: approved (default), pending, rejected, cancelled
ALTER TABLE pos_schema.expense 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'approved';

-- Add rejection_reason column for feedback on rejected requests
ALTER TABLE pos_schema.expense 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Create index for performance on status filtering
CREATE INDEX IF NOT EXISTS idx_expense_status ON pos_schema.expense(status);

COMMIT;

-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- ALTER TABLE pos_schema.expense DROP COLUMN IF EXISTS status;
-- ALTER TABLE pos_schema.expense DROP COLUMN IF EXISTS rejection_reason;
-- COMMIT;
