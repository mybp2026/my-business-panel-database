-- ============================================================
-- Migration purchase-007: auto-apply inventory on PO delivery
-- ------------------------------------------------------------
--   When a purchase_order transitions to status_id = 3
--   ('Delivered'), this trigger receives the goods AND pushes
--   the items into inventory_schema.inventory at the destination
--   warehouse. Composite parents are exploded into their
--   components using product_variant_composition.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION purchase_schema.apply_inventory_on_delivery(
    p_purchase_order_id UUID
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_warehouse_id UUID;
    v_log_in_type_id INTEGER;
    v_item RECORD;
    v_component RECORD;
    v_is_composite BOOLEAN;
    v_total_qty INTEGER;
BEGIN
    -- Resolve destination warehouse for the PO.
    SELECT po.warehouse_id INTO v_warehouse_id
    FROM purchase_schema.purchase_order po
    WHERE po.purchase_order_id = p_purchase_order_id;

    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'apply_inventory_on_delivery: warehouse not found for PO %', p_purchase_order_id;
    END IF;

    -- Resolve 'IN' log type id once.
    SELECT inventory_log_type_id INTO v_log_in_type_id
    FROM inventory_schema.inventory_log_type
    WHERE inventory_log_type_name = 'IN'
    LIMIT 1;

    -- Walk every line of the order.
    FOR v_item IN
        SELECT poi.tenant_id, poi.product_variant_id, poi.quantity_ordered
        FROM purchase_schema.purchase_order_item poi
        WHERE poi.purchase_order_id = p_purchase_order_id
    LOOP
        SELECT pv.is_composite INTO v_is_composite
        FROM general_schema.product_variant pv
        WHERE pv.tenant_id = v_item.tenant_id
          AND pv.product_variant_id = v_item.product_variant_id;

        IF v_is_composite IS TRUE THEN
            -- Composite parent: expand into components and add (qty_ordered * component_qty)
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
            -- Plain variant: add the ordered quantity as-is.
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

COMMENT ON FUNCTION purchase_schema.apply_inventory_on_delivery IS
    'Pushes the items of a delivered purchase_order into inventory at the PO destination warehouse. Expands composite parents into their components.';


CREATE OR REPLACE FUNCTION purchase_schema.upsert_inventory_stock(
    p_tenant_id UUID,
    p_product_variant_id UUID,
    p_warehouse_id UUID,
    p_quantity INTEGER,
    p_log_in_type_id INTEGER
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_id UUID;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RETURN;
    END IF;

    SELECT inventory_id INTO v_existing_id
    FROM inventory_schema.inventory
    WHERE tenant_id = p_tenant_id
      AND product_variant_id = p_product_variant_id
      AND warehouse_id = p_warehouse_id
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        UPDATE inventory_schema.inventory
        SET stock = stock + p_quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE inventory_id = v_existing_id;
    ELSE
        INSERT INTO inventory_schema.inventory(
            tenant_id, product_variant_id, warehouse_id, stock
        ) VALUES (
            p_tenant_id, p_product_variant_id, p_warehouse_id, p_quantity
        );
    END IF;

    IF p_log_in_type_id IS NOT NULL THEN
        INSERT INTO inventory_schema.inventory_log(
            inventory_log_type_id, warehouse_id, tenant_id,
            product_variant_id, quantity
        ) VALUES (
            p_log_in_type_id, p_warehouse_id, p_tenant_id,
            p_product_variant_id, p_quantity
        );
    END IF;
END;
$$;


-- Extend the existing create_goods_receipt trigger so the same status
-- transition that creates the goods_receipt also pushes inventory.
CREATE OR REPLACE FUNCTION purchase_schema.create_goods_receipt()
RETURNS TRIGGER AS $$
DECLARE
    v_goods_receipt_id uuid;
    v_subtotal numeric(12,3);
    v_tax_amount numeric(12,3);
    v_item record;
BEGIN
    IF new.purchase_order_status_id = 3 AND old.purchase_order_status_id IS DISTINCT FROM 3 THEN
        IF NOT EXISTS(
            SELECT 1
            FROM purchase_schema.goods_receipt
            WHERE purchase_order_id = new.purchase_order_id
        ) THEN
            SELECT
                ap.subtotal,
                sap.tax_amount
            INTO v_subtotal, v_tax_amount
            FROM general_schema.account_payable ap
            JOIN purchase_schema.purchase_account_payable sap
                ON ap.account_payable_id = sap.account_payable_id
            WHERE sap.purchase_order_id = new.purchase_order_id;

            INSERT INTO purchase_schema.goods_receipt(
                purchase_order_id,
                received_date,
                subtotal_amount,
                tax_amount
            ) VALUES (
                new.purchase_order_id,
                current_timestamp,
                v_subtotal,
                v_tax_amount
            ) RETURNING goods_receipt_id INTO v_goods_receipt_id;

            FOR v_item IN
                SELECT tenant_id, product_variant_id, quantity_ordered
                FROM purchase_schema.purchase_order_item
                WHERE purchase_order_id = new.purchase_order_id
            LOOP
                INSERT INTO purchase_schema.goods_receipt_item(
                    goods_receipt_id,
                    tenant_id,
                    product_variant_id,
                    quantity_received
                ) VALUES (
                    v_goods_receipt_id,
                    v_item.tenant_id,
                    v_item.product_variant_id,
                    v_item.quantity_ordered
                );
            END LOOP;

            PERFORM purchase_schema.execute_three_way_matching(new.purchase_order_id, v_goods_receipt_id);
        END IF;

        -- Whether or not the goods_receipt already existed, ensure inventory
        -- reflects the delivered items. The function is idempotent if no
        -- items are present, but if the trigger fires twice (which it should
        -- not, since we only fire on a real transition), inventory would
        -- double-count. The `IS DISTINCT FROM 3` guard above protects us.
        PERFORM purchase_schema.apply_inventory_on_delivery(new.purchase_order_id);
    END IF;

    RETURN new;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS create_goods_receipt_trigger ON purchase_schema.purchase_order;
CREATE TRIGGER create_goods_receipt_trigger
    AFTER UPDATE OF purchase_order_status_id ON purchase_schema.purchase_order
    FOR EACH ROW
    EXECUTE FUNCTION purchase_schema.create_goods_receipt();

COMMIT;
