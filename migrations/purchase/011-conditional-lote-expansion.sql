-- Migration purchase-011: Conditional Lote Expansion
-- This migration updates apply_inventory_on_delivery to only expand composite products
-- if the target warehouse is a branch (sales floor).

CREATE OR REPLACE FUNCTION purchase_schema.apply_inventory_on_delivery(
    p_purchase_order_id UUID
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_warehouse_id UUID;
    v_log_in_type_id INTEGER;
    v_item RECORD;
    v_component RECORD;
    v_is_composite BOOLEAN;
    v_total_qty INTEGER;
    v_target_is_branch BOOLEAN;
BEGIN
    SELECT po.warehouse_id INTO v_warehouse_id
    FROM purchase_schema.purchase_order po
    WHERE po.purchase_order_id = p_purchase_order_id;

    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'apply_inventory_on_delivery: warehouse not found for PO %', p_purchase_order_id;
    END IF;

    -- Fetch if the target warehouse is a branch
    SELECT is_branch INTO v_target_is_branch
    FROM inventory_schema.warehouse
    WHERE warehouse_id = v_warehouse_id;

    SELECT inventory_log_type_id INTO v_log_in_type_id
    FROM inventory_schema.inventory_log_type
    WHERE inventory_log_type_name = 'IN'
    LIMIT 1;

    FOR v_item IN
        SELECT poi.tenant_id, poi.product_variant_id, poi.quantity_ordered
        FROM purchase_schema.purchase_order_item poi
        WHERE poi.purchase_order_id = p_purchase_order_id
    LOOP
        SELECT pv.is_composite INTO v_is_composite
        FROM general_schema.product_variant pv
        WHERE pv.tenant_id = v_item.tenant_id
          AND pv.product_variant_id = v_item.product_variant_id;

        -- Only expand if the product is composite AND the target warehouse is a branch (sales floor)
        IF v_is_composite IS TRUE AND v_target_is_branch IS TRUE THEN
            FOR v_component IN
                SELECT pvc.child_product_variant_id, pvc.quantity AS component_qty
                FROM general_schema.product_variant_composition pvc
                WHERE pvc.tenant_id = v_item.tenant_id
                  AND pvc.parent_product_variant_id = v_item.product_variant_id
            LOOP
                v_total_qty := v_item.quantity_ordered * v_component.component_qty;

                PERFORM purchase_schema.upsert_inventory_stock(
                    v_item.tenant_id,
                    v_component.child_product_variant_id,
                    v_warehouse_id,
                    v_total_qty,
                    v_log_in_type_id
                );
            END LOOP;
        ELSE
            -- Treat as a single item if not composite or if it's an auxiliary warehouse
            PERFORM purchase_schema.upsert_inventory_stock(
                v_item.tenant_id,
                v_item.product_variant_id,
                v_warehouse_id,
                v_item.quantity_ordered,
                v_log_in_type_id
            );
        END IF;
    END LOOP;
END;
$$;
