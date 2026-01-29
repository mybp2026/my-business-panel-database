-- ========================================
-- TEST: Category Hierarchy
-- ========================================
-- Description: Tests hierarchical category structure with parent/child relationships
-- Author: David
-- Date: 2026-01-28
-- ========================================

DO $$
DECLARE
    v_cat_root_id int;
    v_cat_electronics_id int;
    v_cat_computers_id int;
    v_cat_laptops_id int;
    v_cat_gaming_laptops_id int;
    v_cat_business_laptops_id int;
    v_cat_ultra_deep_id int;  -- Para probar límite de profundidad
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TEST: Category Hierarchy';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';

    -- ========================================
    -- SECCIÓN 0: Limpieza (Idempotencia)
    -- ========================================
    RAISE NOTICE '🧹 SECCIÓN 0: Limpieza de datos de prueba';
    
    DELETE FROM general_schema.product_category 
    WHERE category_name LIKE 'TEST_%';
    
    RAISE NOTICE '✅ Limpieza completada';
    RAISE NOTICE '';

    -- ========================================
    -- SECCIÓN 1: Categorías Raíz (Level 0)
    -- ========================================

    RAISE NOTICE '📦 SECCIÓN 1: Crear categorías raíz (nivel 0)';
    
    INSERT INTO general_schema.product_category(category_name, parent_category_id)
    VALUES ('TEST_Electronics', NULL)
    RETURNING product_category_id INTO v_cat_root_id;
    
    RAISE NOTICE '  ✓ Categoría raíz creada: % (level should be 0)', v_cat_root_id;
    
    -- Verificar hierarchy_level
    SELECT hierarchy_level INTO v_cat_electronics_id 
    FROM general_schema.product_category 
    WHERE product_category_id = v_cat_root_id;
    
    IF v_cat_electronics_id = 0 THEN
        RAISE NOTICE '  ✓ Hierarchy level correcto: 0';
    ELSE
        RAISE EXCEPTION '  ❌ ERROR: Expected level 0, got %', v_cat_electronics_id;
    END IF;
    RAISE NOTICE '';

    -- ========================================
    -- SECCIÓN 2: Subcategorías (Level 1-3)
    -- ========================================
    RAISE NOTICE '📂 SECCIÓN 2: Crear subcategorías (niveles 1-3)';
    
    -- Level 1
    INSERT INTO general_schema.product_category(category_name, parent_category_id)
    VALUES ('TEST_Computers', v_cat_root_id)
    RETURNING product_category_id INTO v_cat_computers_id;
    RAISE NOTICE '  ✓ Level 1: Computers → %', v_cat_computers_id;
    
    -- Level 2
    INSERT INTO general_schema.product_category(category_name, parent_category_id)
    VALUES ('TEST_Laptops', v_cat_computers_id)
    RETURNING product_category_id INTO v_cat_laptops_id;
    RAISE NOTICE '  ✓ Level 2: Laptops → %', v_cat_laptops_id;
    
    -- Level 3 (múltiples hijos)
    INSERT INTO general_schema.product_category(category_name, parent_category_id)
    VALUES ('TEST_Gaming_Laptops', v_cat_laptops_id)
    RETURNING product_category_id INTO v_cat_gaming_laptops_id;
    
    INSERT INTO general_schema.product_category(category_name, parent_category_id)
    VALUES ('TEST_Business_Laptops', v_cat_laptops_id)
    RETURNING product_category_id INTO v_cat_business_laptops_id;
    
    RAISE NOTICE '  ✓ Level 3: Gaming & Business Laptops creados';
    RAISE NOTICE '';

    -- ========================================
    -- SECCIÓN 3: Prueba de Ciclos (debe fallar)
    -- ========================================
    RAISE NOTICE '🔄 SECCIÓN 3: Probar detección de ciclos';
    
    BEGIN
        -- Intentar crear ciclo: Gaming → Laptops (que es su padre)
        UPDATE general_schema.product_category
        SET parent_category_id = v_cat_gaming_laptops_id
        WHERE product_category_id = v_cat_laptops_id;
        
        RAISE EXCEPTION '❌ ERROR: Se permitió crear un ciclo';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%Cycle detected%' THEN
                RAISE NOTICE '  ✓ Ciclo correctamente detectado y bloqueado';
            ELSE
                RAISE;
            END IF;
    END;
    RAISE NOTICE '';

    -- ========================================
    -- SECCIÓN 4: Límite de Profundidad (debe fallar en nivel 6)
    -- ========================================
    RAISE NOTICE '📏 SECCIÓN 4: Probar límite de profundidad máxima';
    
    -- Level 4 (OK)
    INSERT INTO general_schema.product_category(category_name, parent_category_id)
    VALUES ('TEST_Level_4', v_cat_gaming_laptops_id)
    RETURNING product_category_id INTO v_cat_ultra_deep_id;
    RAISE NOTICE '  ✓ Level 4 creado correctamente';
    
    -- Level 5 (OK - último permitido)
    INSERT INTO general_schema.product_category(category_name, parent_category_id)
    VALUES ('TEST_Level_5', v_cat_ultra_deep_id)
    RETURNING product_category_id INTO v_cat_ultra_deep_id;
    RAISE NOTICE '  ✓ Level 5 creado correctamente (máximo permitido)';
    
    -- Level 6 (debe fallar)
    BEGIN
        INSERT INTO general_schema.product_category(category_name, parent_category_id)
        VALUES ('TEST_Level_6_FAIL', v_cat_ultra_deep_id);
        
        RAISE EXCEPTION '❌ ERROR: Se permitió crear nivel 6';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%Maximum category depth%' THEN
                RAISE NOTICE '  ✓ Límite de profundidad correctamente aplicado';
            ELSE
                RAISE;
            END IF;
    END;
    RAISE NOTICE '';

    -- ========================================
    -- SECCIÓN 5: Función get_subcategories()
    -- ========================================
    RAISE NOTICE '🔍 SECCIÓN 5: Probar función get_subcategories()';
    
    RAISE NOTICE '  Categorías bajo Electronics:';
    FOR v_cat_root_id IN 
        SELECT category_id FROM general_schema.get_subcategories(
            (SELECT product_category_id FROM general_schema.product_category 
             WHERE category_name = 'TEST_Electronics')
        )
    LOOP
        RAISE NOTICE '    - Category ID: %', v_cat_root_id;
    END LOOP;
    
    RAISE NOTICE '  ✓ Función ejecutada correctamente';
    RAISE NOTICE '';

    -- ========================================
    -- SECCIÓN 6: Verificar Categorías sin Hijos
    -- ========================================
    RAISE NOTICE '🍃 SECCIÓN 6: Verificar categorías sin hijos (leaf nodes)';
    
    -- Business Laptops no tiene hijos
    DECLARE
        v_has_children BOOLEAN;
    BEGIN
        SELECT EXISTS(
            SELECT 1 FROM general_schema.product_category
            WHERE parent_category_id = v_cat_business_laptops_id
        ) INTO v_has_children;
        
        IF NOT v_has_children THEN
            RAISE NOTICE '  ✓ Business Laptops es un nodo hoja (sin hijos)';
        ELSE
            RAISE EXCEPTION '❌ ERROR: Business Laptops tiene hijos cuando no debería';
        END IF;
    END;
    
    -- Gaming Laptops SÍ tiene hijos (Level_4 y Level_5)
    DECLARE
        v_child_count INTEGER;
    BEGIN
        WITH RECURSIVE children AS (
            SELECT product_category_id
            FROM general_schema.product_category
            WHERE parent_category_id = v_cat_gaming_laptops_id
            
            UNION ALL
            
            SELECT pc.product_category_id
            FROM general_schema.product_category pc
            INNER JOIN children c ON pc.parent_category_id = c.product_category_id
        )
        SELECT COUNT(*) INTO v_child_count FROM children;
        
        IF v_child_count = 2 THEN
            RAISE NOTICE '  ✓ Gaming Laptops tiene 2 descendientes (Level_4 y Level_5)';
        ELSE
            RAISE EXCEPTION '❌ ERROR: Gaming Laptops tiene % descendientes, esperado 2', v_child_count;
        END IF;
    END;
    
    RAISE NOTICE '';

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ TODOS LOS TESTS PASARON';
    RAISE NOTICE '========================================';
END $$;

