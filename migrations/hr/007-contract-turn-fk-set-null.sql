-- ======================================================
-- MIGRATION: hr/007-contract-turn-fk-set-null.sql
-- ======================================================
-- Author: David
-- Date: 2026-05-14
-- Description:
--   Changes contract.turn_id FK from NO ACTION to SET NULL so
--   that deleting a turn (cascaded from branch deletion) nullifies
--   the contract reference instead of blocking the delete.
--
--   turn_id is already nullable in hr_schema.contract (migration 001).
--
-- Dependencies: hr/006-branch-fk-cascade.sql
-- Breaking Changes: NO
-- ======================================================

BEGIN;

DO $$
DECLARE
  v_constraint TEXT;
BEGIN
  SELECT tc.constraint_name
    INTO v_constraint
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
    JOIN information_schema.referential_constraints rc
      ON rc.constraint_name = tc.constraint_name
    JOIN information_schema.constraint_column_usage ccu
      ON ccu.constraint_name = rc.unique_constraint_name
    WHERE tc.constraint_type  = 'FOREIGN KEY'
      AND tc.table_schema     = 'hr_schema'
      AND tc.table_name       = 'contract'
      AND kcu.column_name     = 'turn_id'
      AND ccu.table_schema    = 'hr_schema'
      AND ccu.table_name      = 'turn'
    LIMIT 1;

  IF v_constraint IS NOT NULL THEN
    EXECUTE format('ALTER TABLE hr_schema.contract DROP CONSTRAINT %I', v_constraint);
    RAISE NOTICE 'Dropped constraint %', v_constraint;
  END IF;
END $$;

ALTER TABLE hr_schema.contract
  ADD CONSTRAINT contract_turn_id_fkey
    FOREIGN KEY (turn_id) REFERENCES hr_schema.turn(turn_id) ON DELETE SET NULL;

COMMIT;

-- ======================================================
-- ROLLBACK (manual):
-- ======================================================
-- BEGIN;
-- ALTER TABLE hr_schema.contract DROP CONSTRAINT IF EXISTS contract_turn_id_fkey;
-- ALTER TABLE hr_schema.contract
--   ADD CONSTRAINT contract_turn_id_fkey
--     FOREIGN KEY (turn_id) REFERENCES hr_schema.turn(turn_id);
-- COMMIT;
