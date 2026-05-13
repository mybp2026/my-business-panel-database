-- ======================================================
-- MIGRATION: pos/031-fix-royalty-option-group-fk.sql
-- Fix royalty_option FK on (tenant_id, tenant_product_group_id) from
-- ON DELETE CASCADE to ON DELETE RESTRICT.
--
-- Root cause of MPR1 (production-only): the CASCADE caused royalty options
-- to be silently deleted whenever a product group was removed or recreated
-- in production. Rules remained but their options disappeared.
--
-- AUDIT: 2026-05-13
-- ======================================================

BEGIN;

-- Drop the auto-named composite FK (PostgreSQL names it based on columns).
-- Using a DO block so it works regardless of the exact auto-generated name.
DO $$
DECLARE
  v_constraint TEXT;
BEGIN
  SELECT conname INTO v_constraint
  FROM pg_constraint
  WHERE conrelid = 'pos_schema.royalty_option'::regclass
    AND contype = 'f'
    AND confrelid = 'general_schema.tenant_product_group'::regclass;

  IF v_constraint IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE pos_schema.royalty_option DROP CONSTRAINT %I',
      v_constraint
    );
  END IF;
END;
$$;

-- Re-add FK with RESTRICT: prevents group deletion if royalty options exist,
-- which forces explicit cleanup instead of silent cascade.
ALTER TABLE pos_schema.royalty_option
    ADD CONSTRAINT fk_royalty_option_group
    FOREIGN KEY (tenant_id, tenant_product_group_id)
    REFERENCES general_schema.tenant_product_group(tenant_id, tenant_product_group_id)
    ON DELETE RESTRICT;

COMMIT;

-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
-- ALTER TABLE pos_schema.royalty_option DROP CONSTRAINT IF EXISTS fk_royalty_option_group;
-- ALTER TABLE pos_schema.royalty_option
--     ADD CONSTRAINT fk_royalty_option_group
--     FOREIGN KEY (tenant_id, tenant_product_group_id)
--     REFERENCES general_schema.tenant_product_group(tenant_id, tenant_product_group_id)
--     ON DELETE CASCADE;
-- COMMIT;
