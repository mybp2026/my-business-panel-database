-- =====================================================
-- TEST: TIPOS DE FACTURA (Digital y Electrónica)
-- =====================================================
-- Este script prueba:
-- 1. Configuración inicial (tenant, productos CABYS, cliente)
-- 2. Creación de venta y pago
-- 3. Generación automática de factura digital (digital_sale_invoice)
-- 4. Creación manual de factura electrónica (electronic_sale_invoice)
-- 5. Vinculación de ítems electrónicos (electronic_sale_invoice_items)
-- 6. Verificación de la bandera has_electronic_invoice en sale
-- 7. Validación de integridad referencial (CABYS codes)
-- =====================================================

-- ========================================
-- SECCIÓN 0: Limpieza inicial
-- ========================================
DO $section_0$
DECLARE
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧹 SECCIÓN 0: Limpieza inicial';
    RAISE NOTICE '========================================';

    -- Limpiar ítems de factura electrónica
    DELETE FROM pos_schema.electronic_sale_invoice_items
    WHERE electronic_sale_invoice_id IN (
        SELECT electronic_sale_invoice_id FROM pos_schema.electronic_sale_invoice
        WHERE sale_id IN (
            SELECT sale_id FROM pos_schema.sale
            WHERE branch_id IN (
                SELECT branch_id FROM general_schema.branch
                WHERE tenant_id IN (
                    SELECT tenant_id FROM general_schema.tenant
                    WHERE tenant_name = 'Facturación Electrónica CR'
                )
            )
        )
    );

    -- Limpiar facturas electrónicas
    DELETE FROM pos_schema.electronic_sale_invoice
    WHERE sale_id IN (
        SELECT sale_id FROM pos_schema.sale
        WHERE branch_id IN (
            SELECT branch_id FROM general_schema.branch
            WHERE tenant_id IN (
                SELECT tenant_id FROM general_schema.tenant
                WHERE tenant_name = 'Facturación Electrónica CR'
            )
        )
    );

    -- Limpiar score_transaction
    DELETE FROM pos_schema.score_transaction
    WHERE tenant_customer_id IN (
        SELECT tenant_customer_id FROM general_schema.tenant_customer
        WHERE email = 'cliente.electronico@email.com'
    );

    -- Limpiar tenant_customer_score
    DELETE FROM pos_schema.tenant_customer_score
    WHERE tenant_customer_id IN (
        SELECT tenant_customer_id FROM general_schema.tenant_customer
        WHERE email = 'cliente.electronico@email.com'
    );

    -- Limpiar digital_sale_invoice_payment
    DELETE FROM pos_schema.digital_sale_invoice_payment
    WHERE digital_sale_invoice_id IN (
        SELECT digital_sale_invoice_id FROM pos_schema.digital_sale_invoice
        WHERE tenant_customer_id IN (
            SELECT tenant_customer_id FROM general_schema.tenant_customer
            WHERE email = 'cliente.electronico@email.com'
        )
    );

    -- Limpiar digital_sale_invoice
    DELETE FROM pos_schema.digital_sale_invoice
    WHERE tenant_customer_id IN (
        SELECT tenant_customer_id FROM general_schema.tenant_customer
        WHERE email = 'cliente.electronico@email.com'
    );

    -- Limpiar customer_payment
    DELETE FROM pos_schema.customer_payment
    WHERE tenant_customer_id IN (
        SELECT tenant_customer_id FROM general_schema.tenant_customer
        WHERE email = 'cliente.electronico@email.com'
    );

    -- Limpiar cash_register_sale
    DELETE FROM pos_schema.cash_register_sale
    WHERE sale_id IN (
        SELECT sale_id FROM pos_schema.sale
        WHERE branch_id IN (
            SELECT branch_id FROM general_schema.branch
            WHERE tenant_id IN (
                SELECT tenant_id FROM general_schema.tenant
                WHERE tenant_name = 'Facturación Electrónica CR'
            )
        )
    );

    -- Limpiar sale_item
    DELETE FROM pos_schema.sale_item
    WHERE sale_id IN (
        SELECT sale_id FROM pos_schema.sale
        WHERE branch_id IN (
            SELECT branch_id FROM general_schema.branch
            WHERE tenant_id IN (
                SELECT tenant_id FROM general_schema.tenant
                WHERE tenant_name = 'Facturación Electrónica CR'
            )
        )
    );

    -- Limpiar sale
    DELETE FROM pos_schema.sale
    WHERE branch_id IN (
        SELECT branch_id FROM general_schema.branch
        WHERE tenant_id IN (
            SELECT tenant_id FROM general_schema.tenant
            WHERE tenant_name = 'Facturación Electrónica CR'
        )
    );

    -- Limpiar cash_register_session
    DELETE FROM pos_schema.cash_register_session
    WHERE cash_register_id IN (
        SELECT cash_register_id FROM pos_schema.cash_register
        WHERE branch_id IN (
            SELECT branch_id FROM general_schema.branch
            WHERE tenant_id IN (
                SELECT tenant_id FROM general_schema.tenant
                WHERE tenant_name = 'Facturación Electrónica CR'
            )
        )
    );

    -- Limpiar cash_register
    DELETE FROM pos_schema.cash_register
    WHERE branch_id IN (
        SELECT branch_id FROM general_schema.branch
        WHERE tenant_id IN (
            SELECT tenant_id FROM general_schema.tenant
            WHERE tenant_name = 'Facturación Electrónica CR'
        )
    );

    -- Limpiar loyalty_program
    DELETE FROM pos_schema.loyalty_program
    WHERE tenant_id IN (
        SELECT tenant_id FROM general_schema.tenant
        WHERE tenant_name = 'Facturación Electrónica CR'
    );

    -- Limpiar tenant_customer
    DELETE FROM general_schema.tenant_customer
    WHERE tenant_id IN (
        SELECT tenant_id FROM general_schema.tenant
        WHERE tenant_name = 'Facturación Electrónica CR'
    );

    -- Limpiar product_variant
    DELETE FROM general_schema.product_variant
    WHERE tenant_id IN (
        SELECT tenant_id FROM general_schema.tenant
        WHERE tenant_name = 'Facturación Electrónica CR'
    );

    -- Limpiar product (CABYS entries de test)
    DELETE FROM general_schema.product WHERE cabys_code IN ('2314001000100', '4323002010100');

    -- Limpiar tax_rate de prueba
    DELETE FROM general_schema.tax_rate WHERE rate_code = 'IVA-13-TEST-FE';

    -- Limpiar users
    DELETE FROM general_schema.users
    WHERE tenant_id IN (
        SELECT tenant_id FROM general_schema.tenant
        WHERE tenant_name = 'Facturación Electrónica CR'
    );

    -- Limpiar branch
    DELETE FROM general_schema.branch
    WHERE tenant_id IN (
        SELECT tenant_id FROM general_schema.tenant
        WHERE tenant_name = 'Facturación Electrónica CR'
    );

    -- Limpiar tenant
    DELETE FROM general_schema.tenant
    WHERE tenant_name = 'Facturación Electrónica CR';

    RAISE NOTICE '✅ Limpieza completada';
    RAISE NOTICE '✅ SECCIÓN 0 COMPLETADA';
    RAISE NOTICE '========================================';
END $section_0$;


-- ========================================
-- SECCIÓN 1: Configuración inicial
-- ========================================
DO $section_1$
DECLARE
    v_tenant_id UUID;
    v_branch_id UUID;
    v_user_id UUID;
    v_customer_id UUID;
    v_variant_a_id UUID;
    v_variant_b_id UUID;
    v_cash_register_id UUID;
    v_loyalty_program_id UUID;
    v_tax_rate_id INTEGER;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🏗️  SECCIÓN 1: Configuración inicial';
    RAISE NOTICE '========================================';

    -- 1.1 Crear tenant (Costa Rica)
    INSERT INTO general_schema.tenant (tenant_name, region_id, contact_email, is_subscribed)
    VALUES ('Facturación Electrónica CR', 1, 'admin@facturacioncr.com', true)
    RETURNING tenant_id INTO v_tenant_id;

    RAISE NOTICE '✅ Tenant creado: %', v_tenant_id;

    -- 1.2 Crear sucursal
    INSERT INTO general_schema.branch (tenant_id, branch_name, branch_address, is_main_branch)
    VALUES (v_tenant_id, 'Sucursal San José', 'Barrio Escalante, Calle 33', true)
    RETURNING branch_id INTO v_branch_id;

    RAISE NOTICE '✅ Sucursal creada: %', v_branch_id;

    -- 1.3 Crear usuario cajero
    INSERT INTO general_schema.users (tenant_id, email, password_hash, role_id)
    VALUES (v_tenant_id, 'cajero@facturacioncr.com', 'hash_fe_test', 1)
    RETURNING user_id INTO v_user_id;

    RAISE NOTICE '✅ Usuario cajero creado: %', v_user_id;

    -- 1.4 Crear cliente con cédula
    INSERT INTO general_schema.tenant_customer (
        tenant_id, first_name, last_name, document_number,
        email, phone, customer_segment_id
    )
    VALUES (
        v_tenant_id, 'María', 'Rodríguez', '1-0987-0654',
        'cliente.electronico@email.com', '+506-7777-1234', 3
    )
    RETURNING tenant_customer_id INTO v_customer_id;

    RAISE NOTICE '✅ Cliente creado: %', v_customer_id;
    RAISE NOTICE '  Nombre: María Rodríguez';
    RAISE NOTICE '  Cédula: 1-0987-0654';

    -- 1.5 Crear entradas CABYS (códigos reales de Costa Rica)
    INSERT INTO general_schema.product (cabys_code, product_name)
    VALUES ('2314001000100', 'Computadoras portátiles')
    ON CONFLICT (cabys_code) DO NOTHING;

    INSERT INTO general_schema.product (cabys_code, product_name)
    VALUES ('4323002010100', 'Teclados para computadora')
    ON CONFLICT (cabys_code) DO NOTHING;

    RAISE NOTICE '✅ Entradas CABYS creadas:';
    RAISE NOTICE '  - 2314001000100: Computadoras portátiles';
    RAISE NOTICE '  - 4323002010100: Teclados para computadora';

    -- 1.5b Crear tasa de impuesto IVA 13%
    INSERT INTO general_schema.tax_rate (rate_percentage, rate_code, rate_name)
    VALUES (13.00, 'I-13-TEST', 'IVA 13% (Test Facturación Electrónica)')
    RETURNING tax_rate_id INTO v_tax_rate_id;

    UPDATE general_schema.product SET tax_rate_id = v_tax_rate_id
    WHERE cabys_code IN ('2314001000100', '4323002010100');

    RAISE NOTICE '✅ Tasa IVA 13%% asignada a productos (tax_rate_id: %)', v_tax_rate_id;

    -- 1.6 Crear variantes vendibles (cada una con su CABYS)
    INSERT INTO general_schema.product_variant (
        tenant_id, cabys_code, sku, variant_name, unit_price, is_active
    )
    VALUES (
        v_tenant_id, '2314001000100', 'FE-LAPTOP-001', 'Laptop Dell Inspiron 15', 650000.00, true
    )
    RETURNING product_variant_id INTO v_variant_a_id;

    INSERT INTO general_schema.product_variant (
        tenant_id, cabys_code, sku, variant_name, unit_price, is_active
    )
    VALUES (
        v_tenant_id, '4323002010100', 'FE-TEC-001', 'Teclado Mecánico RGB', 45000.00, true
    )
    RETURNING product_variant_id INTO v_variant_b_id;

    RAISE NOTICE '✅ Variantes creadas: 2';
    RAISE NOTICE '  - Laptop Dell Inspiron 15: ₡650,000.00 (CABYS: 2314001000100)';
    RAISE NOTICE '  - Teclado Mecánico RGB: ₡45,000.00 (CABYS: 4323002010100)';

    -- 1.7 Crear caja registradora
    INSERT INTO pos_schema.cash_register (branch_id, is_active)
    VALUES (v_branch_id, true)
    RETURNING cash_register_id INTO v_cash_register_id;

    RAISE NOTICE '✅ Caja registradora creada: %', v_cash_register_id;

    -- 1.8 Crear programa de lealtad
    INSERT INTO pos_schema.loyalty_program (
        tenant_id,
        points_earned_per_currency_unit,
        points_redeemed_per_currency_unit,
        minimum_purchase_for_points,
        is_active
    )
    VALUES (
        v_tenant_id,
        1.00,
        100.00,
        0.00,
        true
    )
    RETURNING loyalty_program_id INTO v_loyalty_program_id;

    RAISE NOTICE '✅ Programa de lealtad creado';
    RAISE NOTICE '  Ratio: 1 punto/₡1';
    RAISE NOTICE '✅ SECCIÓN 1 COMPLETADA';
    RAISE NOTICE '========================================';
END $section_1$;


-- ========================================
-- SECCIÓN 2: Abrir sesión de caja
-- ========================================
DO $section_2$
DECLARE
    v_cash_register_id UUID;
    v_user_id UUID;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🖥️ SECCIÓN 2: Abrir sesión de caja';
    RAISE NOTICE '========================================';

    SELECT cr.cash_register_id INTO v_cash_register_id
    FROM pos_schema.cash_register cr
    JOIN general_schema.branch b ON cr.branch_id = b.branch_id
    JOIN general_schema.tenant t ON b.tenant_id = t.tenant_id
    WHERE t.tenant_name = 'Facturación Electrónica CR'
    LIMIT 1;

    SELECT u.user_id INTO v_user_id
    FROM general_schema.users u
    JOIN general_schema.tenant t ON u.tenant_id = t.tenant_id
    WHERE t.tenant_name = 'Facturación Electrónica CR'
    LIMIT 1;

    CALL pos_schema.open_close_cash_register_session(
        v_cash_register_id,
        'open',
        100000.00,
        v_user_id
    );

    RAISE NOTICE '✅ Sesión de caja abierta con fondo: ₡100,000.00';
    RAISE NOTICE '✅ SECCIÓN 2 COMPLETADA';
    RAISE NOTICE '========================================';
END $section_2$;


-- ========================================
-- SECCIÓN 3: Crear venta con productos
-- ========================================
DO $section_3$
DECLARE
    v_tenant_id UUID;
    v_branch_id UUID;
    v_sale_id UUID;
    v_variant_a_id UUID;
    v_variant_b_id UUID;
    v_subtotal NUMERIC(10,2);
    v_tax NUMERIC(10,2);
    v_total NUMERIC(10,2);
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🛒 SECCIÓN 3: Crear venta con productos';
    RAISE NOTICE '========================================';

    SELECT t.tenant_id INTO v_tenant_id
    FROM general_schema.tenant t
    WHERE t.tenant_name = 'Facturación Electrónica CR';

    SELECT b.branch_id INTO v_branch_id
    FROM general_schema.branch b
    WHERE b.tenant_id = v_tenant_id
    LIMIT 1;

    SELECT pv.product_variant_id INTO v_variant_a_id
    FROM general_schema.product_variant pv
    WHERE pv.tenant_id = v_tenant_id AND pv.sku = 'FE-LAPTOP-001';

    SELECT pv.product_variant_id INTO v_variant_b_id
    FROM general_schema.product_variant pv
    WHERE pv.tenant_id = v_tenant_id AND pv.sku = 'FE-TEC-001';

    v_subtotal := 740000.00;
    v_tax := 96200.00;
    v_total := 836200.00;

    INSERT INTO pos_schema.sale (
        branch_id, currency_id, is_completed, has_electronic_invoice,
        subtotal_amount, tax_amount, total_amount
    )
    VALUES (
        v_branch_id, 1, false, false,
        v_subtotal, v_tax, v_total
    )
    RETURNING sale_id INTO v_sale_id;

    RAISE NOTICE '✅ Venta creada: %', v_sale_id;
    RAISE NOTICE '  Subtotal: ₡%.2f', v_subtotal;
    RAISE NOTICE '  IVA (13%%): ₡%.2f', v_tax;
    RAISE NOTICE '  Total: ₡%.2f', v_total;

    INSERT INTO pos_schema.sale_item (
        sale_id, tenant_id, product_variant_id, quantity, unit_price, total_price
    )
    VALUES (
        v_sale_id, v_tenant_id, v_variant_a_id, 1, 650000.00, 650000.00
    );

    INSERT INTO pos_schema.sale_item (
        sale_id, tenant_id, product_variant_id, quantity, unit_price, total_price
    )
    VALUES (
        v_sale_id, v_tenant_id, v_variant_b_id, 2, 45000.00, 90000.00
    );

    RAISE NOTICE '✅ Líneas de venta agregadas:';
    RAISE NOTICE '  - 1x Laptop Dell Inspiron 15 = ₡650,000.00';
    RAISE NOTICE '  - 2x Teclado Mecánico RGB = ₡90,000.00';
    RAISE NOTICE '✅ SECCIÓN 3 COMPLETADA';
    RAISE NOTICE '========================================';
END $section_3$;


-- ========================================
-- SECCIÓN 4: Pago y factura digital automática
-- ========================================
DO $section_4$
DECLARE
    v_sale_id UUID;
    v_customer_id UUID;
    v_payment_count INTEGER;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '💳 SECCIÓN 4: Pago y factura digital automática';
    RAISE NOTICE '========================================';

    SELECT s.sale_id INTO v_sale_id
    FROM pos_schema.sale s
    JOIN general_schema.branch b ON s.branch_id = b.branch_id
    JOIN general_schema.tenant t ON b.tenant_id = t.tenant_id
    WHERE t.tenant_name = 'Facturación Electrónica CR'
    LIMIT 1;

    SELECT tc.tenant_customer_id INTO v_customer_id
    FROM general_schema.tenant_customer tc
    WHERE tc.email = 'cliente.electronico@email.com';

    INSERT INTO pos_schema.customer_payment (
        tenant_customer_id, sale_id, payment_method_id, payment_amount, currency_id, verified
    )
    VALUES (
        v_customer_id, v_sale_id, 1, 836200.00, 1, false
    );

    RAISE NOTICE '✅ Pago registrado: ₡836,200.00 (sin verificar)';

    -- Obtener el último payment_id
    DECLARE
        v_payment_id UUID;
    BEGIN
        SELECT customer_payment_id INTO v_payment_id
        FROM pos_schema.customer_payment 
        WHERE tenant_customer_id = v_customer_id 
        ORDER BY created_at DESC LIMIT 1;

        CALL pos_schema.verify_customer_payment(v_payment_id);
    END;

    RAISE NOTICE '✅ Pago verificado';

    SELECT COUNT(*) INTO v_payment_count
    FROM pos_schema.sale
    WHERE sale_id = v_sale_id AND is_completed = true;

    IF v_payment_count > 0 THEN
        RAISE NOTICE '✅ Venta marcada como completada (is_completed = true)';
    ELSE
        RAISE NOTICE '❌ ERROR: Venta no fue marcada como completada';
    END IF;

    SELECT COUNT(*) INTO v_payment_count
    FROM pos_schema.digital_sale_invoice
    WHERE sale_id = v_sale_id;

    IF v_payment_count > 0 THEN
        RAISE NOTICE '✅ Factura digital creada automáticamente por trigger';
    ELSE
        RAISE NOTICE '❌ ERROR: Factura digital no fue creada';
    END IF;

    RAISE NOTICE '✅ SECCIÓN 4 COMPLETADA';
    RAISE NOTICE '========================================';
END $section_4$;


-- ========================================
-- SECCIÓN 5: Crear factura electrónica (Hacienda)
-- ========================================
DO $section_5$
DECLARE
    v_tenant_id UUID;
    v_sale_id UUID;
    v_customer_id UUID;
    v_electronic_invoice_id UUID;
    v_key_number VARCHAR(50);
    v_consecutive_number VARCHAR(20);
    v_total NUMERIC(18,5);
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '📋 SECCIÓN 5: Crear factura electrónica (Hacienda)';
    RAISE NOTICE '========================================';

    SELECT t.tenant_id INTO v_tenant_id
    FROM general_schema.tenant t
    WHERE t.tenant_name = 'Facturación Electrónica CR';

    SELECT s.sale_id INTO v_sale_id
    FROM pos_schema.sale s
    WHERE s.branch_id IN (
        SELECT b.branch_id FROM general_schema.branch b WHERE b.tenant_id = v_tenant_id
    )
    LIMIT 1;

    SELECT tc.tenant_customer_id INTO v_customer_id
    FROM general_schema.tenant_customer tc
    WHERE tc.email = 'cliente.electronico@email.com';

    v_key_number := '50612025000123456789012345678901234567890123456789';
    v_consecutive_number := '00100100101234567890';
    v_total := 836200.00;

    INSERT INTO pos_schema.electronic_sale_invoice (
        sale_id,
        currency_id,
        key_number,
        consecutive_number,
        issue_date,
        issuer_name,
        issuer_identification,
        issuer_identification_type,
        issuer_email,
        issuer_phone,
        receiver_name,
        receiver_identification,
        receiver_identification_type,
        receiver_email,
        sale_condition,
        payment_method,
        credit_days,
        total_taxed_services,
        total_exempt_services,
        total_exonerated_services,
        total_taxed_goods,
        total_exempt_goods,
        total_exonerated_goods,
        total_taxable,
        total_exempt,
        total_exonerated,
        total_sale,
        total_discounts,
        total_net_sale,
        total_tax,
        total_voucher,
        hacienda_status
    )
    VALUES (
        v_sale_id,
        1,
        v_key_number,
        v_consecutive_number,
        CURRENT_TIMESTAMP,
        'Empresa Test S.A.',
        '3101234567',
        '02',
        'factura@empresa.com',
        '22345678',
        'María Rodríguez',
        '1098706540',
        '01',
        'cliente.electronico@email.com',
        '01',
        '01',
        '0',
        0.00,
        0.00,
        0.00,
        740000.00,
        0.00,
        0.00,
        740000.00,
        0.00,
        0.00,
        740000.00,
        0.00,
        740000.00,
        96200.00,
        836200.00,
        'pending'
    )
    RETURNING electronic_sale_invoice_id INTO v_electronic_invoice_id;

    -- Actualizar bandera has_electronic_invoice
    UPDATE pos_schema.sale SET has_electronic_invoice = true WHERE sale_id = v_sale_id;

    RAISE NOTICE '✅ Factura electrónica creada: %', v_electronic_invoice_id;
    RAISE NOTICE '  Key Number: %', v_key_number;
    RAISE NOTICE '  Consecutive: %', v_consecutive_number;
    RAISE NOTICE '  Total: ₡%.2f', v_total;
    RAISE NOTICE '✅ Bandera has_electronic_invoice actualizada a true';
    RAISE NOTICE '✅ SECCIÓN 5 COMPLETADA';
    RAISE NOTICE '========================================';
END $section_5$;


-- ========================================
-- SECCIÓN 6: Vincular ítems a factura electrónica
-- ========================================
DO $section_6$
DECLARE
    v_tenant_id UUID;
    v_electronic_invoice_id UUID;
    v_sale_id UUID;
    v_variant_a_name VARCHAR(255);
    v_variant_b_name VARCHAR(255);
    v_variant_a_id UUID;
    v_variant_b_id UUID;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '📦 SECCIÓN 6: Vincular ítems a factura electrónica';
    RAISE NOTICE '========================================';

    SELECT t.tenant_id INTO v_tenant_id
    FROM general_schema.tenant t
    WHERE t.tenant_name = 'Facturación Electrónica CR';

    SELECT s.sale_id INTO v_sale_id
    FROM pos_schema.sale s
    WHERE s.branch_id IN (
        SELECT b.branch_id FROM general_schema.branch b WHERE b.tenant_id = v_tenant_id
    )
    LIMIT 1;

    SELECT e.electronic_sale_invoice_id INTO v_electronic_invoice_id
    FROM pos_schema.electronic_sale_invoice e
    WHERE e.sale_id = v_sale_id
    LIMIT 1;

    SELECT pv.variant_name, pv.product_variant_id INTO v_variant_a_name, v_variant_a_id
    FROM general_schema.product_variant pv
    WHERE pv.tenant_id = v_tenant_id AND pv.sku = 'FE-LAPTOP-001';

    SELECT pv.variant_name, pv.product_variant_id INTO v_variant_b_name, v_variant_b_id
    FROM general_schema.product_variant pv
    WHERE pv.tenant_id = v_tenant_id AND pv.sku = 'FE-TEC-001';

    INSERT INTO pos_schema.electronic_sale_invoice_items (
        electronic_sale_invoice_id,
        tenant_id,
        product_variant_id,
        line_number,
        cabys_code,
        description,
        quantity,
        unit_of_measure,
        unit_price,
        total_amount,
        discount_amount,
        subtotal,
        tax_code,
        tax_rate_code,
        tax_rate,
        tax_amount,
        total_line_amount
    )
    VALUES (
        v_electronic_invoice_id,
        v_tenant_id,
        v_variant_a_id,
        1,
        '2314001000100',
        v_variant_a_name,
        1,
        'Unidad',
        650000.00,
        650000.00,
        0.00,
        650000.00,
        '01',
        '08',
        13.00,
        84500.00,
        734500.00
    );

    RAISE NOTICE '✅ Línea 1 agregada: Laptop';

    INSERT INTO pos_schema.electronic_sale_invoice_items (
        electronic_sale_invoice_id,
        tenant_id,
        product_variant_id,
        line_number,
        cabys_code,
        description,
        quantity,
        unit_of_measure,
        unit_price,
        total_amount,
        discount_amount,
        subtotal,
        tax_code,
        tax_rate_code,
        tax_rate,
        tax_amount,
        total_line_amount
    )
    VALUES (
        v_electronic_invoice_id,
        v_tenant_id,
        v_variant_b_id,
        2,
        '4323002010100',
        v_variant_b_name,
        2,
        'Unidad',
        45000.00,
        90000.00,
        0.00,
        90000.00,
        '01',
        '08',
        13.00,
        11700.00,
        101700.00
    );

    RAISE NOTICE '✅ Línea 2 agregada: Teclados';
    RAISE NOTICE '✅ SECCIÓN 6 COMPLETADA';
    RAISE NOTICE '========================================';
END $section_6$;


-- ========================================
-- SECCIÓN 7: Validaciones finales
-- ========================================
DO $section_7$
DECLARE
    v_tenant_id UUID;
    v_sale_id UUID;
    v_digital_count INTEGER;
    v_electronic_count INTEGER;
    v_items_count INTEGER;
    v_has_electronic BOOLEAN;
    v_all_ok BOOLEAN := true;
    invalid_cabys INTEGER;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✔️ SECCIÓN 7: Validaciones finales';
    RAISE NOTICE '========================================';

    SELECT t.tenant_id INTO v_tenant_id
    FROM general_schema.tenant t
    WHERE t.tenant_name = 'Facturación Electrónica CR';

    SELECT s.sale_id INTO v_sale_id
    FROM pos_schema.sale s
    WHERE s.branch_id IN (
        SELECT b.branch_id FROM general_schema.branch b WHERE b.tenant_id = v_tenant_id
    )
    LIMIT 1;

    SELECT COUNT(*) INTO v_digital_count
    FROM pos_schema.digital_sale_invoice
    WHERE sale_id = v_sale_id;

    IF v_digital_count > 0 THEN
        RAISE NOTICE '✅ [OK] Factura digital existe (1 registro)';
    ELSE
        RAISE NOTICE '❌ [ERROR] Factura digital no existe';
        v_all_ok := false;
    END IF;

    SELECT COUNT(*) INTO v_electronic_count
    FROM pos_schema.electronic_sale_invoice
    WHERE sale_id = v_sale_id;

    IF v_electronic_count > 0 THEN
        RAISE NOTICE '✅ [OK] Factura electrónica existe (1 registro)';
    ELSE
        RAISE NOTICE '❌ [ERROR] Factura electrónica no existe';
        v_all_ok := false;
    END IF;

    SELECT COUNT(*) INTO v_items_count
    FROM pos_schema.electronic_sale_invoice_items
    WHERE electronic_sale_invoice_id IN (
        SELECT electronic_sale_invoice_id FROM pos_schema.electronic_sale_invoice
        WHERE sale_id = v_sale_id
    );

    IF v_items_count = 2 THEN
        RAISE NOTICE '✅ [OK] Ítems electrónicos existen (2 registros)';
    ELSE
        RAISE NOTICE '❌ [ERROR] Ítems electrónicos: esperados 2, encontrados %', v_items_count;
        v_all_ok := false;
    END IF;

    SELECT has_electronic_invoice INTO v_has_electronic
    FROM pos_schema.sale
    WHERE sale_id = v_sale_id;

    IF v_has_electronic = true THEN
        RAISE NOTICE '✅ [OK] Bandera has_electronic_invoice = true';
    ELSE
        RAISE NOTICE '❌ [ERROR] Bandera has_electronic_invoice = false';
        v_all_ok := false;
    END IF;

    SELECT COUNT(*) INTO invalid_cabys
    FROM pos_schema.electronic_sale_invoice_items esi
    LEFT JOIN general_schema.product p ON esi.cabys_code = p.cabys_code
    WHERE esi.electronic_sale_invoice_id IN (
        SELECT electronic_sale_invoice_id FROM pos_schema.electronic_sale_invoice
        WHERE sale_id = v_sale_id
    )
    AND p.cabys_code IS NULL;

    IF invalid_cabys = 0 THEN
        RAISE NOTICE '✅ [OK] Todos los CABYS codes son válidos';
    ELSE
        RAISE NOTICE '❌ [ERROR] CABYS codes inválidos encontrados: %', invalid_cabys;
        v_all_ok := false;
    END IF;

    -- Validar digital_sale_invoice_item
    DECLARE
        v_dsii_count INTEGER;
        v_variant_linked INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_dsii_count
        FROM pos_schema.digital_sale_invoice_item dsii
        JOIN pos_schema.digital_sale_invoice dsi ON dsii.digital_sale_invoice_id = dsi.digital_sale_invoice_id
        WHERE dsi.sale_id = v_sale_id;

        IF v_dsii_count = 2 THEN
            RAISE NOTICE '✅ [OK] Ítems de factura digital existen (2 registros)';
        ELSE
            RAISE NOTICE '❌ [ERROR] Ítems de factura digital: esperados 2, encontrados %', v_dsii_count;
            v_all_ok := false;
        END IF;

        -- Validar que electronic_sale_invoice_items tienen product_variant vinculado
        SELECT COUNT(*) INTO v_variant_linked
        FROM pos_schema.electronic_sale_invoice_items esi
        WHERE esi.electronic_sale_invoice_id IN (
            SELECT electronic_sale_invoice_id FROM pos_schema.electronic_sale_invoice
            WHERE sale_id = v_sale_id
        )
        AND esi.tenant_id IS NOT NULL
        AND esi.product_variant_id IS NOT NULL;

        IF v_variant_linked = 2 THEN
            RAISE NOTICE '✅ [OK] Ítems electrónicos vinculados a product_variant (2 registros)';
        ELSE
            RAISE NOTICE '❌ [ERROR] Ítems electrónicos vinculados: esperados 2, encontrados %', v_variant_linked;
            v_all_ok := false;
        END IF;
    END;

    IF v_all_ok = true THEN
        RAISE NOTICE '🎉 TODAS LAS VALIDACIONES PASARON';
    ELSE
        RAISE NOTICE '⚠️ ALGUNAS VALIDACIONES FALLARON';
    END IF;

    RAISE NOTICE '✅ SECCIÓN 7 COMPLETADA';
    RAISE NOTICE '========================================';
END $section_7$;


-- ========================================
-- SECCIÓN 8: Simular respuesta de Hacienda
-- ========================================
DO $section_8$
DECLARE
    v_tenant_id UUID;
    v_electronic_invoice_id UUID;
    v_sale_id UUID;
    v_hacienda_status VARCHAR(20);
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🌐 SECCIÓN 8: Simular respuesta de Hacienda';
    RAISE NOTICE '========================================';

    SELECT t.tenant_id INTO v_tenant_id
    FROM general_schema.tenant t
    WHERE t.tenant_name = 'Facturación Electrónica CR';

    SELECT s.sale_id INTO v_sale_id
    FROM pos_schema.sale s
    WHERE s.branch_id IN (
        SELECT b.branch_id FROM general_schema.branch b WHERE b.tenant_id = v_tenant_id
    )
    LIMIT 1;

    SELECT e.electronic_sale_invoice_id INTO v_electronic_invoice_id
    FROM pos_schema.electronic_sale_invoice e
    WHERE e.sale_id = v_sale_id
    LIMIT 1;

    UPDATE pos_schema.electronic_sale_invoice
    SET
        hacienda_status = 'accepted',
        hacienda_response_date = CURRENT_TIMESTAMP,
        hacienda_response_xml = '<respuestaHacienda><clave>50612025000123456789012345678901234567890123456789</clave><estado>aceptado</estado></respuestaHacienda>'
    WHERE electronic_sale_invoice_id = v_electronic_invoice_id;

    SELECT hacienda_status INTO v_hacienda_status
    FROM pos_schema.electronic_sale_invoice
    WHERE electronic_sale_invoice_id = v_electronic_invoice_id;

    RAISE NOTICE '✅ Respuesta de Hacienda simulada';
    RAISE NOTICE '  Estado: %', v_hacienda_status;
    RAISE NOTICE '  Fecha: %', CURRENT_TIMESTAMP;
    RAISE NOTICE '✅ SECCIÓN 8 COMPLETADA';
    RAISE NOTICE '========================================';
END $section_8$;


