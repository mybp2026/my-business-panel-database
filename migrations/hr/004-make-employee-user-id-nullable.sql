-- ======================================================
-- MIGRATION: hr/004-make-employee-user-id-nullable.sql
-- ======================================================
-- Author: David
-- Date: 2026-05-11
-- Description: Makes hr_schema.employee.user_id nullable so employees
--   without system access accounts can be registered (e.g. janitors,
--   security guards). The FK is re-created with ON DELETE SET NULL so
--   deleting a user does not cascade-delete the employee record.
-- Dependencies: hr_schema initial setup
-- Breaking Changes: NO (relaxes NOT NULL constraint)
-- Rollback: See bottom of file
-- ======================================================

BEGIN;

ALTER TABLE hr_schema.employee ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE hr_schema.employee DROP CONSTRAINT IF EXISTS employee_user_id_fkey;
ALTER TABLE hr_schema.employee
  ADD CONSTRAINT employee_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES general_schema.users(user_id) ON DELETE SET NULL;

COMMIT;

-- ======================================================
-- ROLLBACK (run manually if needed):
-- ======================================================
-- BEGIN;
-- UPDATE hr_schema.employee SET is_active = false WHERE user_id IS NULL;
-- ALTER TABLE hr_schema.employee DROP CONSTRAINT IF EXISTS employee_user_id_fkey;
-- ALTER TABLE hr_schema.employee ALTER COLUMN user_id SET NOT NULL;
-- ALTER TABLE hr_schema.employee
--   ADD CONSTRAINT employee_user_id_fkey
--   FOREIGN KEY (user_id) REFERENCES general_schema.users(user_id) ON DELETE CASCADE;
-- COMMIT;
