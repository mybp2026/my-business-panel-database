-- ============================================
-- TEST: CRUD WAREHOUSE & INVENTORY (IDEMPOTENTE)
-- ============================================
-- Objetivo: Probar creación, lectura, actualización y eliminación
--            para `warehouse` e `inventory`, y validar constraints.
-- ============================================

-- ========================================
-- SECCIÓN 0: Limpieza inicial (idempotente)
-- ========================================
DO $$
DECLARE
    v_warehouse_name VARCHAR := 'test_warehouse_mvp';
    v_warehouse_id uuid;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧹 SECCIÓN 0: Limpieza inicial';
    RAISE NOTICE '========================================';

    SELECT warehouse_id INTO v_warehouse_id
    FROM inventory_schema.warehouse
    WHERE warehouse_name = v_warehouse_name
    LIMIT 1;

    IF v_warehouse_id IS NOT NULL THEN
        DELETE FROM inventory_schema.inventory WHERE warehouse_id = v_warehouse_id;
        DELETE FROM inventory_schema.warehouse WHERE warehouse_id = v_warehouse_id;
        RAISE NOTICE '   ✓ Warehouse and related inventory removed: %', v_warehouse_id;
    ELSE
        RAISE NOTICE '   No existing test warehouse found';
    END IF;

    -- actualizar limpieza inicial para eliminar también warehouse_dest/tmp
    FOR v_warehouse_id IN
        SELECT warehouse_id
        FROM inventory_schema.warehouse
        WHERE warehouse_name IN (
            'test_warehouse_mvp',
            'test_warehouse_mvp_updated',
            'test_warehouse_dest',
            'test_warehouse_mvp_tmp'
        )
    LOOP
        DELETE FROM inventory_schema.inventory WHERE warehouse_id = v_warehouse_id;
        DELETE FROM inventory_schema.warehouse WHERE warehouse_id = v_warehouse_id;
        RAISE NOTICE '   ✓ Warehouse and related inventory removed: %', v_warehouse_id;
    END LOOP;

    RAISE NOTICE '✅ Limpieza completada';
    RAISE NOTICE '========================================';
END $$;

-- ========================================
-- SECCIÓN 1: Creación de warehouse e inventory
-- ========================================
DO $$
DECLARE
    v_warehouse_id uuid;
    v_branch_id uuid := (SELECT branch_id FROM general_schema.branch LIMIT 1);
    v_tenant_id uuid;
    v_product_id uuid;
    v_inventory_id uuid;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📦 SECCIÓN 1: Creación de warehouse e inventory';
    RAISE NOTICE '========================================';

    IF v_branch_id IS NULL THEN
        RAISE EXCEPTION 'No hay registros en general_schema.branch. Inserte al menos una branch en general_schema.branch';
    END IF;

    -- Crear warehouse
    INSERT INTO inventory_schema.warehouse(branch_id, warehouse_name, warehouse_address)
    VALUES (v_branch_id, 'test_warehouse_mvp', 'Address 123')
    RETURNING warehouse_id INTO v_warehouse_id;

    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'Error: no se creó warehouse';
    END IF;
    RAISE NOTICE '   ✓ Warehouse creado: %', v_warehouse_id;

    -- Obtener un product_variant existente para inventory (tenant_id, product_variant_id)
    SELECT tenant_id, product_variant_id INTO v_tenant_id, v_product_id FROM general_schema.product_variant LIMIT 1;
    IF v_product_id IS NULL THEN
        -- Si no hay product_variant, limpiamos y abortamos test
        DELETE FROM inventory_schema.inventory WHERE warehouse_id = v_warehouse_id;
        DELETE FROM inventory_schema.warehouse WHERE warehouse_id = v_warehouse_id;
        RAISE EXCEPTION 'No hay registros en general_schema.product_variant. Inserte al menos un product_variant';
    END IF;

    -- Insertar inventory válido
    INSERT INTO inventory_schema.inventory(tenant_id, product_variant_id, warehouse_id, stock, expiration_date)
    VALUES (v_tenant_id, v_product_id, v_warehouse_id, 100, current_timestamp + interval '30 days')
    RETURNING inventory_id INTO v_inventory_id;

    IF v_inventory_id IS NULL THEN
        RAISE EXCEPTION 'Error: no se creó inventory';
    END IF;
    RAISE NOTICE '   ✓ Inventory creado: %', v_inventory_id;

    RAISE NOTICE '✅ SECCIÓN 1 COMPLETADA';
    RAISE NOTICE '========================================';
END $$ LANGUAGE plpgsql;

-- ========================================
-- SECCIÓN 2: Lectura y validaciones
-- ========================================
DO $$
DECLARE
    v_warehouse_id uuid;
    v_inventory_count int;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 SECCIÓN 2: Lectura y validaciones';
    RAISE NOTICE '========================================';

    SELECT warehouse_id INTO v_warehouse_id FROM inventory_schema.warehouse WHERE warehouse_name = 'test_warehouse_mvp' LIMIT 1;
    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'No se encontró el warehouse de prueba';
    END IF;

    SELECT count(*) INTO v_inventory_count FROM inventory_schema.inventory WHERE warehouse_id = v_warehouse_id;
    RAISE NOTICE '   Inventories found for warehouse %: %', v_warehouse_id, v_inventory_count;

    IF v_inventory_count = 0 THEN
        RAISE EXCEPTION 'No se halló inventory asociado al warehouse';
    END IF;

    RAISE NOTICE '✅ SECCIÓN 2 COMPLETADA';
    RAISE NOTICE '========================================';
END $$ LANGUAGE plpgsql;

-- ========================================
-- SECCIÓN 3: Actualización
-- ========================================
DO $$
DECLARE
    v_warehouse_id uuid;
    v_inventory_id uuid;
    v_old_stock INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✏️ SECCIÓN 3: Actualización';
    RAISE NOTICE '========================================';

    SELECT warehouse_id INTO v_warehouse_id FROM inventory_schema.warehouse WHERE warehouse_name = 'test_warehouse_mvp' LIMIT 1;
    SELECT inventory_id, stock INTO v_inventory_id, v_old_stock FROM inventory_schema.inventory WHERE warehouse_id = v_warehouse_id LIMIT 1;

    IF v_inventory_id IS NULL THEN
        RAISE EXCEPTION 'No hay inventory para actualizar';
    END IF;

    -- Actualizar stock
    UPDATE inventory_schema.inventory SET stock = stock + 50 WHERE inventory_id = v_inventory_id;
    RAISE NOTICE '   ✓ Stock actualizado de % a %', v_old_stock, v_old_stock + 50;

    -- Actualizar warehouse_name
    UPDATE inventory_schema.warehouse SET warehouse_name = 'test_warehouse_mvp_updated', updated_at = current_timestamp WHERE warehouse_id = v_warehouse_id;
    RAISE NOTICE '   ✓ Warehouse name actualizado: %', v_warehouse_id;

    RAISE NOTICE '✅ SECCIÓN 3 COMPLETADA';
    RAISE NOTICE '========================================';
END $$ LANGUAGE plpgsql;

-- ========================================
-- SECCIÓN 3.5: Transferencia entre warehouses
-- ========================================
DO $$
DECLARE
    v_origin uuid;
    v_dest uuid;
    v_tenant uuid;
    v_product uuid;
    v_transfer_id uuid;
    v_before_origin int;
    v_after_origin int;
    v_before_dest int;
    v_after_dest int;
    v_log_count int;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔁 SECCIÓN 3.5: Transferencia entre warehouses';
    RAISE NOTICE '========================================';

    SELECT tenant_id, product_variant_id INTO v_tenant, v_product
      FROM general_schema.product_variant LIMIT 1;

    SELECT warehouse_id INTO v_origin
      FROM inventory_schema.warehouse
      WHERE warehouse_name = 'test_warehouse_mvp_updated' LIMIT 1;

    INSERT INTO inventory_schema.warehouse(branch_id, warehouse_name, warehouse_address)
    VALUES (
        (SELECT branch_id FROM inventory_schema.warehouse WHERE warehouse_id = v_origin),
        'test_warehouse_dest',
        'address dest'
    )
    RETURNING warehouse_id INTO v_dest;

    -- stock inicial en ambas bodegas
    INSERT INTO inventory_schema.inventory(tenant_id, warehouse_id, product_variant_id,
       stock, expiration_date, created_at, updated_at)
    VALUES (v_tenant, v_dest, v_product, 5, current_timestamp + interval '30 days', NOW(), NOW());

    SELECT stock INTO v_before_origin
      FROM inventory_schema.inventory
      WHERE warehouse_id = v_origin AND product_variant_id = v_product;
    SELECT stock INTO v_before_dest
      FROM inventory_schema.inventory
      WHERE warehouse_id = v_dest AND product_variant_id = v_product;

    -- reproducimos la lógica que debe hacer el servicio
    BEGIN
        INSERT INTO inventory_schema.inventory_transfer
            (from_warehouse_id, to_warehouse_id, transfer_date, created_at, updated_at)
        VALUES (v_origin, v_dest, NOW(), NOW(), NOW())
        RETURNING inventory_transfer_id INTO v_transfer_id;

        UPDATE inventory_schema.inventory
        SET stock = GREATEST(0, stock - 10), updated_at = NOW()
        WHERE warehouse_id = v_origin AND product_variant_id = v_product AND tenant_id = v_tenant;

        UPDATE inventory_schema.inventory
        SET stock = stock + 10, updated_at = NOW()
        WHERE warehouse_id = v_dest AND product_variant_id = v_product AND tenant_id = v_tenant;

        INSERT INTO inventory_schema.inventory_transfer_product
            (inventory_transfer_id, tenant_id, product_variant_id, quantity, created_at, updated_at)
        VALUES (v_transfer_id, v_tenant, v_product, 10, NOW(), NOW());

        INSERT INTO inventory_schema.inventory_log
            (inventory_log_type_id, warehouse_id, tenant_id, product_variant_id, quantity, created_at, updated_at)
       VALUES   (2, v_origin, v_tenant, v_product, 10, NOW(), NOW()),
                (1, v_dest,   v_tenant, v_product, 10, NOW(), NOW());
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Transferencia fallida: %', SQLERRM;
    END;

    SELECT stock INTO v_after_origin
      FROM inventory_schema.inventory
      WHERE warehouse_id = v_origin AND product_variant_id = v_product;
    SELECT stock INTO v_after_dest
      FROM inventory_schema.inventory
      WHERE warehouse_id = v_dest AND product_variant_id = v_product;

    IF v_after_origin <> v_before_origin - 10 OR v_after_dest <> v_before_dest + 10 THEN
        RAISE EXCEPTION 'La transferencia no actualizó correctamente los stocks';
    END IF;

    SELECT count(*) INTO v_log_count
      FROM inventory_schema.inventory_log
      WHERE warehouse_id IN (v_origin, v_dest) AND product_variant_id = v_product;
    IF v_log_count <> 2 THEN
        RAISE EXCEPTION 'No se registraron correctamente los logs, encontrados %', v_log_count;
    END IF;

    -- limpiar bodega destino
    DELETE FROM inventory_schema.inventory WHERE warehouse_id = v_dest;
    DELETE FROM inventory_schema.warehouse WHERE warehouse_id = v_dest;
END $$ LANGUAGE plpgsql;

-- ========================================
-- SECCIÓN 4: Borrado y validación de cascada
-- ========================================
DO $$
DECLARE
    v_warehouse_id uuid;
    v_inventory_count int;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🗑️ SECCIÓN 4: Borrado y validación de cascada';
    RAISE NOTICE '========================================';

    SELECT warehouse_id INTO v_warehouse_id FROM inventory_schema.warehouse WHERE warehouse_name = 'test_warehouse_mvp_updated' LIMIT 1;
    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'No se encontró el warehouse actualizado para borrar';
    END IF;

    DELETE FROM inventory_schema.warehouse WHERE warehouse_id = v_warehouse_id;
    RAISE NOTICE '   ✓ Warehouse eliminado: %', v_warehouse_id;

    SELECT count(*) INTO v_inventory_count FROM inventory_schema.inventory WHERE warehouse_id = v_warehouse_id;
    IF v_inventory_count = 0 THEN
        RAISE NOTICE '   ✅ Cascade delete confirmado: no hay inventory para %', v_warehouse_id;
    ELSE
        RAISE EXCEPTION 'Inventory no fue eliminado por cascade: % registros restantes', v_inventory_count;
    END IF;

    RAISE NOTICE '✅ SECCIÓN 4 COMPLETADA';
    RAISE NOTICE '========================================';
END $$ LANGUAGE plpgsql;

-- ========================================
-- SECCIÓN 5: Validación de constraint (expiration_date)
-- ========================================
DO $$
DECLARE
    v_branch_id uuid := (SELECT branch_id FROM general_schema.branch LIMIT 1);
    v_warehouse_id uuid;
    v_tenant_id uuid;
    v_product_id uuid;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🛡️ SECCIÓN 5: Validación de constraint (expiration_date)';
    RAISE NOTICE '========================================';

    -- Recrear warehouse temporal para probar constraint
    INSERT INTO inventory_schema.warehouse(branch_id, warehouse_name, warehouse_address)
    VALUES (v_branch_id, 'test_warehouse_mvp_tmp', 'Address tmp')
    RETURNING warehouse_id INTO v_warehouse_id;

    SELECT tenant_id, product_variant_id INTO v_tenant_id, v_product_id FROM general_schema.product_variant LIMIT 1;
    IF v_product_id IS NULL THEN
        DELETE FROM inventory_schema.warehouse WHERE warehouse_id = v_warehouse_id;
        RAISE EXCEPTION 'No hay registros en general_schema.product_variant. Inserte al menos un product_variant';
    END IF;

    RAISE NOTICE '   Forzando inserción inválida (expiration_date en el pasado)';
    BEGIN
        INSERT INTO inventory_schema.inventory(tenant_id, product_variant_id, warehouse_id, stock, expiration_date)
        VALUES (v_tenant_id, v_product_id, v_warehouse_id, 1, current_timestamp - interval '1 day');

        RAISE EXCEPTION '❌ Fallo de prueba: Se permitió la inserción inválida de inventory';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLSTATE = '23514' THEN
                RAISE NOTICE '   ✅ EXITO. Inserción bloqueada por constraint de expiration_date';
            ELSE
                RAISE EXCEPTION 'Se lanzó una excepción inesperada: %', SQLERRM;
            END IF;
    END;

    -- Limpieza del warehouse temporal
    DELETE FROM inventory_schema.inventory WHERE warehouse_id = v_warehouse_id;
    DELETE FROM inventory_schema.warehouse WHERE warehouse_id = v_warehouse_id;

    RAISE NOTICE '✅ SECCIÓN 5 COMPLETADA';
    RAISE NOTICE '========================================';
END $$ LANGUAGE plpgsql;

-- ========================================
-- SECCIÓN 6: Resumen final
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 SECCIÓN 6: RESUMEN FINAL';
    RAISE NOTICE '========================================';
    RAISE NOTICE '   ✅ TEST WAREHOUSE & INVENTORY FINALIZADO EXITOSAMENTE';
    RAISE NOTICE '========================================';
END $$ LANGUAGE plpgsql;
