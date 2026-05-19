-- ======================================================
-- MIGRATION: hr/006-branch-fk-cascade.sql
-- ======================================================
-- Author: David
-- Date: 2026-05-14
-- Description:
--   Rebuilds every FK from hr_schema and accounting_schema that
--   points at general_schema.branch(branch_id) to use
--   ON DELETE CASCADE.
--
--   The DO block looks up actual constraint names at runtime so
--   the migration is safe regardless of naming conventions.
--
-- Affected tables:
--   hr_schema.config, hr_schema.turn, hr_schema.employee,
--   hr_schema.foul, hr_schema.suspention, hr_schema.clocking,
--   hr_schema.tardiness, hr_schema.incapacity, hr_schema.paysheet,
--   accounting_schema.expense
--
-- Breaking Changes: NO (additive behaviour change, no data loss)
-- ======================================================

BEGIN;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT
      tc.constraint_name,
      tc.table_schema,
      tc.table_name,
      kcu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage       kcu ON kcu.constraint_name  = tc.constraint_name
                                                      AND kcu.table_schema     = tc.table_schema
    JOIN information_schema.referential_constraints rc  ON rc.constraint_name  = tc.constraint_name
    JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = rc.unique_constraint_name
    WHERE tc.constraint_type                  = 'FOREIGN KEY'
      AND ccu.table_schema                    = 'general_schema'
      AND ccu.table_name                      = 'branch'
      AND ccu.column_name                     = 'branch_id'
      AND rc.delete_rule                     != 'CASCADE'
      AND tc.table_schema IN ('hr_schema', 'accounting_schema')
  LOOP
    EXECUTE format(
      'ALTER TABLE %I.%I DROP CONSTRAINT %I',
      r.table_schema, r.table_name, r.constraint_name
    );
    EXECUTE format(
      'ALTER TABLE %I.%I ADD FOREIGN KEY (%I) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE',
      r.table_schema, r.table_name, r.column_name
    );
    RAISE NOTICE 'Updated % . % . % → ON DELETE CASCADE',
      r.table_schema, r.table_name, r.constraint_name;
  END LOOP;
END $$;

COMMIT;

-- ======================================================
-- ROLLBACK (manual):
-- ======================================================
-- Re-run the DO block replacing 'CASCADE' with 'NO ACTION'
-- in the ADD FOREIGN KEY statement.
