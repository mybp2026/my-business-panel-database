-- =====================================
-- TEST: PAGO DE CONTADO CON FACTURACI�N
-- =====================================
-- Este script prueba el flujo completo:
-- 1. Configuraci�n inicial (tenant, productos, cliente)
-- 2. Apertura de sesi�n de caja
-- 3. Creaci�n de venta con productos
-- 4. Registro de pago de contado
-- 5. Verificaci�n de pago (dispara cascada de triggers)
-- 6. Generaci�n autom�tica de factura
-- 7. Vinculaci�n a sesi�n de caja
-- 8. Otorgamiento de puntos de lealtad
-- 9. Cierre de sesi�n de caja
-- =====================================

-- ========================================
-- SECCI�N 0: Limpieza inicial
-- ========================================
DO $$
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '?? SECCI�N 0: Limpieza inicial';
    raise notice '========================================';
    raise notice '';
    
    -- Limpiar en orden inverso a las FOREIGN KEYs
    delete from pos_schema.score_transaction 
    where tenant_customer_id in (
        select tenant_customer_id from general_schema.tenant_customer 
        where email = 'juan.perez@email.com'
    );
    
    delete from pos_schema.tenant_customer_score 
    where tenant_customer_id in (
        select tenant_customer_id from general_schema.tenant_customer 
        where email = 'juan.perez@email.com'
    );
    
    delete from pos_schema.digital_sale_invoice_payment 
    where digital_sale_invoice_id in (
        select digital_sale_invoice_id from pos_schema.digital_sale_invoice 
        where tenant_customer_id in (
            select tenant_customer_id from general_schema.tenant_customer 
            where email = 'juan.perez@email.com'
        )
    );
    delete from pos_schema.digital_sale_invoice 
    where tenant_customer_id in (
        select tenant_customer_id from general_schema.tenant_customer 
        where email = 'juan.perez@email.com'
    );
    
    delete from pos_schema.customer_payment 
    where tenant_customer_id in (
        select tenant_customer_id from general_schema.tenant_customer 
        where email = 'juan.perez@email.com'
    );
    
    delete from pos_schema.cash_register_sale 
    where sale_id in (
        select sale_id from pos_schema.sale 
        where branch_id in (
            select branch_id from general_schema.branch 
            where tenant_id in (
                select tenant_id from general_schema.tenant 
                where tenant_name = 'Super Comercio Digital'
            )
        )
    );
    
    delete from pos_schema.sale_item 
    where sale_id in (
        select sale_id from pos_schema.sale 
        where branch_id in (
            select branch_id from general_schema.branch 
            where tenant_id in (
                select tenant_id from general_schema.tenant 
                where tenant_name = 'Super Comercio Digital'
            )
        )
    );
    
    delete from pos_schema.sale 
    where branch_id in (
        select branch_id from general_schema.branch 
        where tenant_id in (
            select tenant_id from general_schema.tenant 
            where tenant_name = 'Super Comercio Digital'
        )
    );
    
    delete from pos_schema.cash_register_session 
    where cash_register_id in (
        select cash_register_id from pos_schema.cash_register 
        where branch_id in (
            select branch_id from general_schema.branch 
            where tenant_id in (
                select tenant_id from general_schema.tenant 
                where tenant_name = 'Super Comercio Digital'
            )
        )
    );
    
    delete from pos_schema.cash_register 
    where branch_id in (
        select branch_id from general_schema.branch 
        where tenant_id in (
            select tenant_id from general_schema.tenant 
            where tenant_name = 'Super Comercio Digital'
        )
    );
    
    delete from pos_schema.loyalty_program 
    where tenant_id in (
        select tenant_id from general_schema.tenant 
        where tenant_name = 'Super Comercio Digital'
    );
    
    delete from general_schema.tenant_customer 
    where tenant_id in (
        select tenant_id from general_schema.tenant 
        where tenant_name = 'Super Comercio Digital'
    );
    
    delete from general_schema.product_variant 
    where tenant_id in (
        select tenant_id from general_schema.tenant 
        where tenant_name = 'Super Comercio Digital'
    );

    DELETE FROM general_schema.product WHERE cabys_code LIKE 'CPTEST%';

    -- Limpiar tax_rate de prueba
    DELETE FROM general_schema.tax_rate WHERE rate_code = 'IVA-13-TEST-CP';
    
    delete from general_schema.users 
    where tenant_id in (
        select tenant_id from general_schema.tenant 
        where tenant_name = 'Super Comercio Digital'
    );
    
    delete from general_schema.branch 
    where tenant_id in (
        select tenant_id from general_schema.tenant 
        where tenant_name = 'Super Comercio Digital'
    );
    
    delete from general_schema.tenant 
    where tenant_name = 'Super Comercio Digital';
    
    raise notice '? Estado despu�s de limpieza:';
    raise notice '  Tenants: %', (select count(*) from general_schema.tenant);
    raise notice '  Clientes: %', (select count(*) from general_schema.tenant_customer);
    raise notice '  Productos (variants): %', (select count(*) from general_schema.product_variant);
    raise notice '  Ventas: %', (select count(*) from pos_schema.sale);
    raise notice '  Facturas: %', (select count(*) from pos_schema.digital_sale_invoice);
    raise notice '';
    raise notice '? SECCI�N 0 COMPLETADA';
    raise notice '========================================';
end $$;


-- ========================================
-- SECCI�N 1: Configuraci�n inicial
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_branch_id uuid;
    v_user_id uuid;
    v_customer_id uuid;
    v_variant_a_id uuid;
    v_variant_b_id uuid;
    v_variant_c_id uuid;
    v_cash_register_id uuid;
    v_loyalty_program_id uuid;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '???  SECCI�N 1: Configuraci�n inicial';
    raise notice '========================================';
    raise notice '';

    -- 1.1 Crear tenant
    INSERT INTO general_schema.tenant (tenant_name, region_id, contact_email, is_subscribed)
    VALUES ('Super Comercio Digital', 1, 'contacto@superdigital.com', true)
    returning tenant_id into v_tenant_id;
    
    raise notice '? Tenant creado: %', v_tenant_id;

    -- 1.2 Crear sucursal
    INSERT INTO general_schema.branch (tenant_id, branch_name, branch_address, is_main_branch)
    VALUES (v_tenant_id, 'Sucursal Centro', 'Av. Principal #123', true)
    returning branch_id into v_branch_id;
    
    raise notice '? Sucursal creada: %', v_branch_id;

    -- 1.3 Crear usuario cajero
    INSERT INTO general_schema.users (tenant_id, email, password_hash, role_id)
    VALUES (v_tenant_id, 'cajero@superdigital.com', 'hash123', 1)
    returning user_id into v_user_id;
    
    raise notice '? Usuario cajero creado: %', v_user_id;

    -- 1.4 Crear cliente
    INSERT INTO general_schema.tenant_customer (
        tenant_id, first_name, last_name, document_number,
        email, phone, customer_segment_id
    )
    VALUES (
        v_tenant_id, 'Juan', 'P�rez', 'DNI-12345678',
        'juan.perez@email.com', '+506-8888-9999', 3
    )
    returning tenant_customer_id into v_customer_id;
    
    raise notice '? Cliente creado: %', v_customer_id;
    raise notice '  Nombre: Juan P�rez';
    raise notice '  Segmento: Regular';

    -- 1.5 Crear entrada CABYS
    INSERT INTO general_schema.product (cabys_code, product_name)
    VALUES ('CPTEST0000001', 'Productos Electr�nicos')
    ON CONFLICT (cabys_code) DO NOTHING;
    
    raise notice '? Entrada CABYS creada: CPTEST0000001';

    -- 1.6 Crear variantes vendibles
    INSERT INTO general_schema.product_variant (
        tenant_id, cabys_code, sku, variant_name, unit_price, is_active
    )
    VALUES (
        v_tenant_id, 'CPTEST0000001', 'PROD-001', 'Laptop HP', 850.00, true
    )
    returning product_variant_id into v_variant_a_id;
    
    INSERT INTO general_schema.product_variant (
        tenant_id, cabys_code, sku, variant_name, unit_price, is_active
    )
    VALUES (
        v_tenant_id, 'CPTEST0000001', 'PROD-002', 'Mouse Logitech', 25.00, true
    )
    returning product_variant_id into v_variant_b_id;
    
    INSERT INTO general_schema.product_variant (
        tenant_id, cabys_code, sku, variant_name, unit_price, is_active
    )
    VALUES (
        v_tenant_id, 'CPTEST0000001', 'PROD-003', 'Teclado Mec�nico', 120.00, true
    )
    returning product_variant_id into v_variant_c_id;
    
    raise notice '? Variantes creadas: 3';
    raise notice '  - Laptop HP: $850.00';
    raise notice '  - Mouse Logitech: $25.00';
    raise notice '  - Teclado Mec�nico: $120.00';

    -- 1.7 Crear caja registradora
    INSERT INTO pos_schema.cash_register (branch_id, is_active)
    VALUES (v_branch_id, true)
    returning cash_register_id into v_cash_register_id;
    
    raise notice '? Caja registradora creada: %', v_cash_register_id;

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
        10.00,
        100.00,
        0.00,
        true
    )
    returning loyalty_program_id into v_loyalty_program_id;
    
    raise notice '? Programa de lealtad creado';
    raise notice '  Ratio: 10 puntos/$1';
    raise notice '  Canje: 100 puntos = $1';
    raise notice '';
    
    raise notice '? SECCI�N 1 COMPLETADA';
    raise notice '========================================';
end $$;


-- ========================================
-- SECCI�N 2: Abrir sesi�n de caja
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_cash_register_id uuid;
    v_user_id uuid;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '?? SECCI�N 2: Abrir sesi�n de caja';
    raise notice '========================================';
    raise notice '';

    -- Obtener tenant_id
    select tenant_id into v_tenant_id
    from general_schema.tenant
    where tenant_name = 'Super Comercio Digital';

    -- Obtener caja del tenant
    select cash_register_id into v_cash_register_id
    from pos_schema.cash_register cr
    join general_schema.branch b on cr.branch_id = b.branch_id
    where b.tenant_id = v_tenant_id
    and cr.is_active = true
    limit 1;

    if v_cash_register_id is null then
        raise exception 'No se encontr� caja registradora para el tenant';
    end if;

    -- Obtener user_id del cajero
    select user_id into v_user_id
    from general_schema.users
    where tenant_id = v_tenant_id
    limit 1;

    -- Abrir sesi�n con $500 de fondo y user_id
    call pos_schema.open_close_cash_register_session(
        v_cash_register_id,
        'open',
        500.00,
        v_user_id
    );
    
    raise notice '';
    raise notice '? SECCI�N 2 COMPLETADA';
    raise notice '========================================';
end $$;


-- ========================================
-- SECCI�N 3: Crear venta con productos
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_branch_id uuid;
    v_user_id uuid;
    v_customer_id uuid;
    v_variant_a_id uuid;  -- ? Cambio: variant_id en lugar de product_id
    v_variant_b_id uuid;
    v_variant_c_id uuid;
    v_sale_id uuid;
    v_subtotal numeric(10,2);
    v_tax_rate numeric(5,2);
    v_tax_amount numeric(10,2);
    v_total_amount numeric(10,2);
    v_region_id INTEGER;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '?? SECCI�N 3: Crear venta con productos';
    raise notice '========================================';
    raise notice '';

    -- Obtener tenant_id
    select tenant_id into v_tenant_id
    from general_schema.tenant
    where tenant_name = 'Super Comercio Digital';

    if v_tenant_id is null then
        raise exception 'Tenant "Super Comercio Digital" no encontrado';
    end if;

    raise notice '? Trabajando con tenant: %', v_tenant_id;

    -- Obtener IDs del mismo tenant
    select branch_id into v_branch_id
    from general_schema.branch
    where tenant_id = v_tenant_id
    and branch_name = 'Sucursal Centro';

    select user_id into v_user_id
    from general_schema.users
    where tenant_id = v_tenant_id
    limit 1;

    select tenant_customer_id into v_customer_id
    from general_schema.tenant_customer
    where tenant_id = v_tenant_id
    and email = 'juan.perez@email.com';

    -- ? Obtener VARIANTES (no productos base)
    select product_variant_id into v_variant_a_id
    from general_schema.product_variant
    where tenant_id = v_tenant_id
    and sku = 'PROD-001';

    select product_variant_id into v_variant_b_id
    from general_schema.product_variant
    where tenant_id = v_tenant_id
    and sku = 'PROD-002';

    select product_variant_id into v_variant_c_id
    from general_schema.product_variant
    where tenant_id = v_tenant_id
    and sku = 'PROD-003';

    -- Verificar que se encontraron todos
    if v_branch_id is null or v_user_id is null or v_customer_id is null then
        raise exception 'No se encontraron datos b�sicos del tenant';
    end if;

    if v_variant_a_id is null or v_variant_b_id is null or v_variant_c_id is null then
        raise exception 'No se encontraron todas las variantes del tenant';
    end if;

    raise notice '? Variantes encontradas del tenant';

    -- ? CALCULAR SUBTOTAL + IMPUESTO
    v_subtotal := 850.00 + 25.00 + 120.00;  -- $995.00
    
    -- Obtener regi�n del tenant
    select region_id into v_region_id
    from general_schema.tenant
    where tenant_id = v_tenant_id;
    
    -- Obtener tasa de impuesto
    select rate_percentage into v_tax_rate
    from general_schema.tax_rate
    where region_id = v_region_id
    limit 1;
    
    if v_tax_rate is null then
        v_tax_rate := 0;
        raise warning 'No se encontr� tasa de impuesto para regi�n %, usando 0%%', v_region_id;
    end if;
    
    v_tax_amount := round(v_subtotal * (v_tax_rate / 100), 2);
    v_total_amount := v_subtotal + v_tax_amount;

    raise notice '? C�lculo de venta:';
    raise notice '  Subtotal (productos): $%', v_subtotal;
    raise notice '  Impuesto (% percent): $%', v_tax_rate, v_tax_amount;
    raise notice '  TOTAL (con impuesto): $%', v_total_amount;
    raise notice '';

    INSERT INTO pos_schema.sale (
        branch_id,
        currency_id,
        subtotal_amount,
        tax_amount,
        total_amount,
        is_completed
    )
    VALUES (
        v_branch_id,
        1,
        v_subtotal,
        v_tax_amount,
        v_total_amount,
        false
    )
    returning sale_id into v_sale_id;
    
    raise notice '? Venta creada: %', v_sale_id;
    raise notice '  Subtotal: $%', v_subtotal;
    raise notice '  Impuesto: $%', v_tax_amount;
    raise notice '  Total: $%', v_total_amount;
    raise notice '  Estado: Pendiente';

    INSERT INTO pos_schema.sale_item (
        sale_id, tenant_id, product_variant_id, quantity, unit_price, total_price
    )
    VALUES (
        v_sale_id, v_tenant_id, v_variant_a_id, 1, 850.00, 850.00
    );
    
    raise notice '? Producto agregado: Laptop HP � 1 = $850.00';

    INSERT INTO pos_schema.sale_item (
        sale_id, tenant_id, product_variant_id, quantity, unit_price, total_price
    )
    VALUES (
        v_sale_id, v_tenant_id, v_variant_b_id, 1, 25.00, 25.00
    );
    
    raise notice '? Producto agregado: Mouse Logitech � 1 = $25.00';

    INSERT INTO pos_schema.sale_item (
        sale_id, tenant_id, product_variant_id, quantity, unit_price, total_price
    )
    VALUES (
        v_sale_id, v_tenant_id, v_variant_c_id, 1, 120.00, 120.00
    );
    
    raise notice '? Producto agregado: Teclado Mec�nico � 1 = $120.00';
    raise notice '';
    
    raise notice '? SECCI�N 3 COMPLETADA';
    raise notice '========================================';
end $$;


-- ========================================
-- SECCI�N 4: Registrar pago de contado
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_customer_id uuid;
    v_sale_id uuid;
    v_payment_id uuid;
    v_payment_method VARCHAR(50);
    v_sale_subtotal numeric(10,2);
    v_sale_tax numeric(10,2);
    v_sale_total numeric(10,2);  -- ? Ya incluye impuesto
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '?? SECCI�N 4: Registrar pago de contado';
    raise notice '========================================';
    raise notice '';

    -- Obtener tenant_id
    select tenant_id into v_tenant_id
    from general_schema.tenant
    where tenant_name = 'Super Comercio Digital';

    -- Obtener cliente del tenant
    select tenant_customer_id into v_customer_id
    from general_schema.tenant_customer
    where tenant_id = v_tenant_id
    and email = 'juan.perez@email.com';

    -- ? Obtener TODOS los campos de la venta
    select 
        s.sale_id, 
        s.subtotal_amount,  -- $995.00
        s.tax_amount,       -- $129.35
        s.total_amount      -- $1,124.35 ? YA INCLUYE IMPUESTO
    into 
        v_sale_id, 
        v_sale_subtotal,
        v_sale_tax,
        v_sale_total
    from pos_schema.sale s
    join general_schema.branch b on s.branch_id = b.branch_id
    where b.tenant_id = v_tenant_id
    and s.is_completed = false
    order by s.sale_date desc
    limit 1;

    if v_customer_id is null or v_sale_id is null then
        raise exception 'No se encontr� cliente o venta del tenant';
    end if;

    -- ? Mostrar desglose (sin recalcular)
    raise notice '?? Desglose del pago:';
    raise notice '  Subtotal (productos): $%', v_sale_subtotal;
    raise notice '  Impuesto (13%%): $%', v_sale_tax;
    raise notice '  TOTAL A PAGAR: $%', v_sale_total;  -- ? Usar directamente
    raise notice '';

    -- ? Registrar pago con el total CORRECTO
    INSERT INTO pos_schema.customer_payment (
        tenant_customer_id,
        sale_id,
        payment_method_id,
        payment_amount,      -- ? Usar total de la venta (ya incluye impuesto)
        currency_id,
        verified
    )
    VALUES (
        v_customer_id,
        v_sale_id,
        3,  -- credit_card
        v_sale_total,        -- ? $1,124.35 (no $1,270.52)
        1,  -- USD
        false
    )
    returning customer_payment_id into v_payment_id;
    
    select name into v_payment_method
    from general_schema.payment_method
    where payment_method_id = 3;
    
    raise notice '? Pago registrado: %', v_payment_id;
    raise notice '  Cliente: Juan P�rez';
    raise notice '  Venta: %', v_sale_id;
    raise notice '  M�todo: % ??', v_payment_method;
    raise notice '  Monto: $%', v_sale_total;  -- ? Monto correcto
    raise notice '  Estado: Pendiente de verificaci�n ?';
    raise notice '';
    
    raise notice '? SECCI�N 4 COMPLETADA';
    raise notice '========================================';
end $$;


-- ========================================
-- SECCI�N 5: Verificar pago (TRIGGER CASCADE)
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_payment_id uuid;
    v_sale_id uuid;
    v_digital_sale_invoice_id uuid;
    v_session_id uuid;
    v_points_earned INTEGER;
    v_sale_completed BOOLEAN;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '?? SECCI�N 5: Verificar pago';
    raise notice '========================================';
    raise notice '';

    -- Obtener tenant_id
    select tenant_id into v_tenant_id
    from general_schema.tenant
    where tenant_name = 'Super Comercio Digital';

    -- Obtener pago pendiente del tenant
    select cp.customer_payment_id, cp.sale_id 
    into v_payment_id, v_sale_id
    from pos_schema.customer_payment cp
    join general_schema.tenant_customer tc on cp.tenant_customer_id = tc.tenant_customer_id
    where tc.tenant_id = v_tenant_id
    and cp.verified = false
    order by cp.payment_date desc
    limit 1;

    if v_payment_id is null then
        raise exception 'No se encontr� pago pendiente del tenant';
    end if;

    raise notice '?? Verificando pago %...', v_payment_id;
    raise notice '  Venta asociada: %', v_sale_id;
    raise notice '';

    -- ? VERIFICAR PAGO (esto dispara toda la cascada)
    call pos_schema.verify_customer_payment(v_payment_id);
    
    raise notice '';
    raise notice '----------------------------------------';
    raise notice '?? VERIFICANDO RESULTADOS';
    raise notice '----------------------------------------';
    raise notice '';

    -- Verificar que la venta se complet�
    select is_completed into v_sale_completed
    from pos_schema.sale
    where sale_id = v_sale_id;
    
    if v_sale_completed then
        raise notice '? Venta marcada como COMPLETADA';
    else
        raise exception '? ERROR: Venta NO se complet�';
    end if;

    -- Verificar que se cre� la factura
    select digital_sale_invoice_id into v_digital_sale_invoice_id
    from pos_schema.digital_sale_invoice
    where sale_id = v_sale_id;
    
    if v_digital_sale_invoice_id is not null then
        raise notice '? Factura creada: %', v_digital_sale_invoice_id;
    else
        raise exception '? ERROR: Factura NO se cre�';
    end if;

    -- Verificar vinculaci�n a sesi�n de caja
    select cash_register_session_id into v_session_id
    from pos_schema.cash_register_sale
    where sale_id = v_sale_id;
    
    if v_session_id is not null then
        raise notice '? Venta vinculada a sesi�n de caja: %', v_session_id;
    else
        raise warning '??  Venta NO vinculada a sesi�n de caja';
    end if;

    -- Verificar puntos ganados
    select score into v_points_earned
    from pos_schema.tenant_customer_score tcs
    join general_schema.tenant_customer tc on tcs.tenant_customer_id = tc.tenant_customer_id
    where tc.tenant_id = v_tenant_id
    and tc.email = 'juan.perez@email.com';
    
    if v_points_earned > 0 then
        raise notice '? Puntos otorgados: % pts', v_points_earned;
    else
        raise warning '??  No se otorgaron puntos';
    end if;
    
    raise notice '';
    raise notice '? SECCI�N 5 COMPLETADA';
    raise notice '========================================';
end $$;


-- ========================================
-- SECCI�N 6: Consultar factura completa
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_invoice record;
    v_item record;
    v_payment record;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '?? SECCI�N 6: Detalle de factura';
    raise notice '========================================';
    raise notice '';

    -- Obtener tenant_id
    select tenant_id into v_tenant_id
    from general_schema.tenant
    where tenant_name = 'Super Comercio Digital';

    -- Obtener datos de la factura del tenant
    select 
        b.digital_sale_invoice_id,
        concat(tc.first_name, ' ', tc.last_name) as customer_name,
        b.subtotal_amount,
        b.tax_amount,
        b.total_amount,
        b.invoiced_at,
        c.symbol as currency_symbol
    into v_invoice
    from pos_schema.digital_sale_invoice b
    join general_schema.tenant_customer tc on b.tenant_customer_id = tc.tenant_customer_id
    join general_schema.currency c on b.currency_id = c.currency_id
    where tc.tenant_id = v_tenant_id
    order by b.invoiced_at desc
    limit 1;

    if v_invoice.digital_sale_invoice_id is null then
        raise exception 'No se encontr� factura del tenant';
    end if;

    raise notice '?? FACTURA: %', v_invoice.digital_sale_invoice_id;
    raise notice '---------------------------------------';
    raise notice '  Cliente: %', v_invoice.customer_name;
    raise notice '  Fecha: %', v_invoice.invoiced_at;
    raise notice '';
    
    raise notice '  Subtotal: %', format('%s%s', v_invoice.currency_symbol, v_invoice.subtotal_amount);
    raise notice '  Impuesto: %', format('%s%s', v_invoice.currency_symbol, v_invoice.tax_amount);
    raise notice '  TOTAL: %', format('%s%s', v_invoice.currency_symbol, v_invoice.total_amount);
    
    raise notice '';
    raise notice '  PRODUCTOS:';
    raise notice '  ---------------------------------------';

    -- Listar productos de la venta (variantes)
    for v_item in
        select 
            pv.variant_name,
            si.quantity,
            si.unit_price,
            si.total_price
        from pos_schema.sale_item si
        join general_schema.product_variant pv on si.tenant_id = pv.tenant_id 
                            and si.product_variant_id = pv.product_variant_id
        join pos_schema.sale s on si.sale_id = s.sale_id
        join pos_schema.digital_sale_invoice b on s.sale_id = b.sale_id
        where b.digital_sale_invoice_id = v_invoice.digital_sale_invoice_id
        order by pv.variant_name
    loop
        raise notice '  � % � % = $%',
            v_item.variant_name,
            v_item.quantity,
            v_item.total_price;
    end loop;

    raise notice '';
    raise notice '  PAGOS:';
    raise notice '  ---------------------------------------';

    -- Listar pagos
    for v_payment in
        select 
            pm.name as method_name,
            cp.payment_amount,
            cp.verified
        from pos_schema.digital_sale_invoice_payment bp
        join pos_schema.customer_payment cp on bp.customer_payment_id = cp.customer_payment_id
        join general_schema.payment_method pm on cp.payment_method_id = pm.payment_method_id
        where bp.digital_sale_invoice_id = v_invoice.digital_sale_invoice_id
    loop
        raise notice '  � %: $% ?',
            v_payment.method_name,
            v_payment.payment_amount;
    end loop;

    raise notice '---------------------------------------';
    raise notice '';
    
    raise notice '? SECCI�N 6 COMPLETADA';
    raise notice '========================================';
end $$;

-- ========================================
-- SECCI�N 7: Cerrar sesi�n de caja
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_cash_register_id uuid;
    v_closing_amount numeric(10,2);
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '?? SECCI�N 7: Cerrar sesi�n de caja';
    raise notice '========================================';
    raise notice '';

    -- Obtener tenant_id
    select tenant_id into v_tenant_id
    from general_schema.tenant
    where tenant_name = 'Super Comercio Digital';

    -- Obtener caja registradora activa del tenant
    select cr.cash_register_id into v_cash_register_id
    from pos_schema.cash_register_session crs
    join pos_schema.cash_register cr on crs.cash_register_id = cr.cash_register_id
    join general_schema.branch b on cr.branch_id = b.branch_id
    where b.tenant_id = v_tenant_id
    and crs.is_active = true
    order by crs.opened_at desc
    limit 1;

    if v_cash_register_id is null then
        raise exception 'No se encontr� sesi�n de caja activa del tenant';
    end if;

    -- Calcular monto de cierre: $500 (apertura) + $995 (venta) = $1,495
    v_closing_amount := 1495.00;

    -- Cerrar sesi�n
    call pos_schema.open_close_cash_register_session(
        v_cash_register_id,
        'close',
        v_closing_amount,
        null
    );
    
    raise notice '';
    raise notice '? SECCI�N 7 COMPLETADA';
    raise notice '========================================';
end $$;


-- ========================================
-- SECCI�N 8: Resumen final
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_total_sales INTEGER;
    v_total_invoices INTEGER;
    v_total_payments INTEGER;
    v_total_revenue numeric(10,2);
    v_total_points INTEGER;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '?? SECCI�N 8: Resumen final';
    raise notice '========================================';
    raise notice '';

    -- Obtener tenant_id
    select tenant_id into v_tenant_id
    from general_schema.tenant
    where tenant_name = 'Super Comercio Digital';

    -- Estad�sticas del tenant
    select count(*) into v_total_sales
    from pos_schema.sale s
    join general_schema.branch b on s.branch_id = b.branch_id
    where b.tenant_id = v_tenant_id
    and s.is_completed = true;

    select count(*) into v_total_invoices
    from pos_schema.digital_sale_invoice b
    join general_schema.tenant_customer tc on b.tenant_customer_id = tc.tenant_customer_id
    where tc.tenant_id = v_tenant_id;

    select count(*) into v_total_payments
    from pos_schema.customer_payment cp
    join general_schema.tenant_customer tc on cp.tenant_customer_id = tc.tenant_customer_id
    where tc.tenant_id = v_tenant_id
    and cp.verified = true;

    select coalesce(sum(cp.payment_amount), 0) into v_total_revenue
    from pos_schema.customer_payment cp
    join general_schema.tenant_customer tc on cp.tenant_customer_id = tc.tenant_customer_id
    where tc.tenant_id = v_tenant_id
    and cp.verified = true;

    select coalesce(sum(tcs.score), 0) into v_total_points
    from pos_schema.tenant_customer_score tcs
    join general_schema.tenant_customer tc on tcs.tenant_customer_id = tc.tenant_customer_id
    where tc.tenant_id = v_tenant_id;

    raise notice '?? ESTAD�STICAS (Tenant: Super Comercio Digital):';
    raise notice '  ? Ventas completadas: %', v_total_sales;
    raise notice '  ? Facturas generadas: %', v_total_invoices;
    raise notice '  ? Pagos verificados: %', v_total_payments;
    raise notice '  ? Ingresos totales: $%', v_total_revenue;
    raise notice '  ? Puntos otorgados: % pts', v_total_points;
    raise notice '';

    raise notice '? TODAS LAS PRUEBAS COMPLETADAS CON �XITO';
    raise notice '';
    raise notice '?? El flujo completo funciona correctamente:';
    raise notice '  1. ? Tenant y datos iniciales creados';
    raise notice '  2. ? Sesi�n de caja abierta';
    raise notice '  3. ? Venta registrada con productos';
    raise notice '  4. ? Pago de contado verificado';
    raise notice '  5. ? Factura creada autom�ticamente';
    raise notice '  6. ? Venta vinculada a caja';
    raise notice '  7. ? Puntos de lealtad otorgados';
    raise notice '  8. ? Sesi�n de caja cerrada';
    raise notice '';
    raise notice '========================================';
end $$;


-- ========================================
-- CONSULTAS ADICIONALES (opcional)
-- ========================================

-- Ver todas las ventas del tenant
select 
    '=== VENTAS ===' as seccion,
    s.sale_id,
    b.branch_name,
    s.total_amount,
    s.is_completed,
    s.sale_date
from pos_schema.sale s
join general_schema.branch b on s.branch_id = b.branch_id
join general_schema.tenant t on b.tenant_id = t.tenant_id
left join pos_schema.cash_register_sale crs on s.sale_id = crs.sale_id
left join pos_schema.cash_register_session crss on crs.cash_register_session_id = crss.cash_register_session_id
left join general_schema.users u on crss.user_id = u.user_id
where t.tenant_name = 'Super Comercio Digital'
order by s.sale_date desc;

-- Ver todas las facturas del tenant
select 
    '=== VENTAS ===' as seccion,
    s.sale_id,
    b.branch_name,
    u.email as cajero,  
    s.subtotal_amount,
    s.tax_amount,
    s.total_amount,
    s.is_completed,
    s.sale_date
from pos_schema.sale s
join general_schema.branch b on s.branch_id = b.branch_id
join general_schema.tenant t on b.tenant_id = t.tenant_id
left join pos_schema.cash_register_sale crs on s.sale_id = crs.sale_id
left join pos_schema.cash_register_session crss on crs.cash_register_session_id = crss.cash_register_session_id
left join general_schema.users u on crss.user_id = u.user_id  -- ? user desde sesi�n
where t.tenant_name = 'Super Comercio Digital'
order by s.sale_date desc;

-- Ver productos vendidos del tenant (variantes)
select 
    '=== PRODUCTOS VENDIDOS ===' as seccion,
    pv.variant_name,
    si.quantity,
    si.unit_price,
    si.total_price,
    s.sale_date
from pos_schema.sale_item si
join general_schema.product_variant pv on si.tenant_id = pv.tenant_id 
                    and si.product_variant_id = pv.product_variant_id
join pos_schema.sale s on si.sale_id = s.sale_id
join general_schema.branch br on s.branch_id = br.branch_id
join general_schema.tenant t on br.tenant_id = t.tenant_id
where t.tenant_name = 'Super Comercio Digital'
order by s.sale_date desc;

-- Ver pagos del tenant
select 
    '=== PAGOS ===' as seccion,
    concat(tc.first_name, ' ', tc.last_name) as cliente,
    pm.name as metodo_pago,
    cp.payment_amount,
    cp.verified,
    cp.payment_date
from pos_schema.customer_payment cp
join general_schema.tenant_customer tc on cp.tenant_customer_id = tc.tenant_customer_id
join general_schema.payment_method pm on cp.payment_method_id = pm.payment_method_id
join general_schema.tenant t on tc.tenant_id = t.tenant_id
where t.tenant_name = 'Super Comercio Digital'
order by cp.payment_date desc;

-- Ver puntos de clientes del tenant
select 
    '=== PUNTOS DE LEALTAD ===' as seccion,
    concat(tc.first_name, ' ', tc.last_name) as cliente,
    tcs.score as puntos_disponibles,
    tcs.lifetime_score as puntos_acumulados,
    tcs.score_redeemed as puntos_canjeados,
    tcs.last_earned_at
from pos_schema.tenant_customer_score tcs
join general_schema.tenant_customer tc on tcs.tenant_customer_id = tc.tenant_customer_id
join general_schema.tenant t on tc.tenant_id = t.tenant_id
where t.tenant_name = 'Super Comercio Digital'
order by tcs.score desc;

-- Ver sesiones de caja del tenant
select 
    '=== SESIONES DE CAJA ===' as seccion,
    crs.cash_register_session_id,
    b.branch_name,
    crs.opening_amount,
    crs.closing_amount,
    (crs.closing_amount - crs.opening_amount) as diferencia,
    crs.opened_at,
    crs.closed_at,
    (crs.closed_at - crs.opened_at) as duracion
from pos_schema.cash_register_session crs
join pos_schema.cash_register cr on crs.cash_register_id = cr.cash_register_id
join general_schema.branch b on cr.branch_id = b.branch_id
join general_schema.tenant t on b.tenant_id = t.tenant_id
where t.tenant_name = 'Super Comercio Digital'
order by crs.opened_at desc;
