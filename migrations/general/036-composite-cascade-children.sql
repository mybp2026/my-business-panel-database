-- ============================================================================
-- MIGRATION: general/036-composite-cascade-children.sql
-- Date: 2026-05-19
-- Description: Adds a BEFORE DELETE trigger on product_variant that cascades
--              deletion to child variants when a composite parent is deleted.
--
--              Algorithm (per child):
--                1. Remove all composition rows where this child appears as
--                   child_product_variant_id (satisfies RESTRICT constraint).
--                2. Delete the child variant — fires trigger recursively if
--                   the child itself is_composite.
--
--              Edge cases handled:
--                - Children shared across multiple composite parents are deleted
--                  when the first parent is deleted (by design, see spec).
--                - Deeply nested composites handled via recursive trigger calls.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION general_schema.cascade_delete_composite_children()
RETURNS TRIGGER AS $$
DECLARE
    v_child_id UUID;
BEGIN
    IF OLD.is_composite THEN
        FOR v_child_id IN
            SELECT child_product_variant_id
            FROM general_schema.product_variant_composition
            WHERE tenant_id = OLD.tenant_id
              AND parent_product_variant_id = OLD.product_variant_id
        LOOP
            -- Remove ALL composition rows where this variant appears as a child
            -- (from any parent). Required to satisfy ON DELETE RESTRICT before
            -- deleting the variant row itself.
            DELETE FROM general_schema.product_variant_composition
            WHERE tenant_id = OLD.tenant_id
              AND child_product_variant_id = v_child_id;

            -- Delete the child variant. If the child is_composite, this DELETE
            -- fires the trigger recursively, cascading to its own children.
            DELETE FROM general_schema.product_variant
            WHERE tenant_id = OLD.tenant_id
              AND product_variant_id = v_child_id;
        END LOOP;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_cascade_delete_composite_children
    BEFORE DELETE ON general_schema.product_variant
    FOR EACH ROW EXECUTE FUNCTION general_schema.cascade_delete_composite_children();

COMMIT;


-- ============================================================================
-- ROLLBACK
-- ============================================================================
-- BEGIN;
-- DROP TRIGGER IF EXISTS trg_cascade_delete_composite_children ON general_schema.product_variant;
-- DROP FUNCTION IF EXISTS general_schema.cascade_delete_composite_children();
-- COMMIT;
