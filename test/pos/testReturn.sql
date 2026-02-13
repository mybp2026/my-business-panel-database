-- =====================================
-- SCRIPT DE PRUEBA: DEVOLUCIONES PARCIALES Y TOTALES (idempotente)
-- =====================================
-- Sections follow the same style as testHybridPay.sql
-- 1) Cleanup (idempotent)
-- 2) Prepare tenant/branch/user/customer/products
-- 3) Create sale and digital_sale_invoice (via verify_customer_payment trigger)
-- 4) Perform PARTIAL return (less than purchased quantity)
-- 5) Verify invoice and sale updated and return_product rows created
-- 6) Perform TOTAL return of remaining items
-- 7) Verify invoice and sale zeroed and return_product rows created
-- =====================================

set local search_path = general_schema, pos_schema;

-- ========================================
-- SECCIÓN 0: Limpieza inicial (idempotente)
-- ========================================
DO $$
declare
    v_tenant_id uuid;
BEGIN
    raise notice '========================================';
    raise notice '🧹 SECCIÓN 0: Limpieza inicial (idempotente)';
    raise notice '========================================';

    select tenant_id into v_tenant_id from general_schema.tenant where tenant_name = 'Return Test Shop' limit 1;

    if v_tenant_id is not null then

        delete from pos_schema.return_product where return_transaction_id in (
            select return_transaction_id from pos_schema.return_transaction rt
            join pos_schema.digital_sale_invoice b on rt.digital_sale_invoice_id = b.digital_sale_invoice_id
            join pos_schema.sale s on b.sale_id = s.sale_id
            join general_schema.branch br on s.branch_id = br.branch_id
            where br.tenant_id = v_tenant_id
        );

        delete from pos_schema.return_transaction where digital_sale_invoice_id in (
            select b.digital_sale_invoice_id from pos_schema.digital_sale_invoice b
            join pos_schema.sale s on b.sale_id = s.sale_id
            join general_schema.branch br on s.branch_id = br.branch_id
            where br.tenant_id = v_tenant_id
        );

        delete from pos_schema.digital_sale_invoice_payment where digital_sale_invoice_id in (
            select b.digital_sale_invoice_id from pos_schema.digital_sale_invoice b
            join pos_schema.sale s on b.sale_id = s.sale_id
            join general_schema.branch br on s.branch_id = br.branch_id
            where br.tenant_id = v_tenant_id
        );

        delete from pos_schema.digital_sale_invoice where sale_id in (
            select s.sale_id from pos_schema.sale s
            join general_schema.branch br on s.branch_id = br.branch_id
            where br.tenant_id = v_tenant_id
        );

        delete from pos_schema.customer_payment where sale_id in (
            select s.sale_id from pos_schema.sale s
            join general_schema.branch br on s.branch_id = br.branch_id
            where br.tenant_id = v_tenant_id
        );

        delete from pos_schema.sale_item where tenant_id = v_tenant_id;
        delete from pos_schema.sale where branch_id in (
            select branch_id from general_schema.branch where tenant_id = v_tenant_id
        );

        delete from pos_schema.cash_register_sale where cash_register_session_id in (
            select cash_register_session_id from pos_schema.cash_register_session crs
            join pos_schema.cash_register cr on crs.cash_register_id = cr.cash_register_id
            join general_schema.branch br on cr.branch_id = br.branch_id
            where br.tenant_id = v_tenant_id
        );

        delete from pos_schema.cash_register_session where cash_register_id in (
            select cash_register_id from pos_schema.cash_register cr
            join general_schema.branch br on cr.branch_id = br.branch_id
            where br.tenant_id = v_tenant_id
        );

        delete from pos_schema.cash_register where branch_id in (
            select branch_id from general_schema.branch where tenant_id = v_tenant_id
        );

        delete from pos_schema.score_transaction where tenant_id = v_tenant_id;
        delete from pos_schema.tenant_customer_score where tenant_id = v_tenant_id;
        delete from pos_schema.loyalty_program where tenant_id = v_tenant_id;

        delete from general_schema.product_variant where tenant_id = v_tenant_id;
        DELETE FROM general_schema.product WHERE cabys_code LIKE 'RTTEST%';

        -- Limpiar tax_rate de prueba
        DELETE FROM general_schema.tax_rate WHERE rate_code = 'IVA-10-TEST-RT';

        delete from general_schema.tenant_customer where tenant_id = v_tenant_id;
        delete from general_schema.users where tenant_id = v_tenant_id;
        delete from general_schema.branch where tenant_id = v_tenant_id;
        delete from general_schema.tenant where tenant_id = v_tenant_id;

        raise notice '   Previous test data removed for tenant %', v_tenant_id;
    else
        raise notice '   No previous test tenant found, nothing to clean';
    end if;

    raise notice '✅ SECCIÓN 0 COMPLETADA';
    raise notice '========================================';
end $$;


-- ========================================
-- SECCIÓN 1: Preparación completa de datos (idempotente)
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_branch_id uuid;
    v_user_id uuid;
    v_customer_id uuid;
    v_prod_a uuid;
    v_prod_b uuid;
    v_prod_c uuid;
    v_cash_reg uuid;
    v_tax_rate_id INTEGER;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '🏪 SECCIÓN 1: Preparación de datos';
    raise notice '========================================';

    select tenant_id into v_tenant_id from general_schema.tenant where tenant_name = 'Return Test Shop' limit 1;
    if v_tenant_id is null then
        INSERT INTO general_schema.tenant(tenant_name, region_id, contact_email, is_subscribed)
        VALUES ('Return Test Shop', (select region_id from general_schema.region limit 1), 'returns@testshop.com', false)
        returning tenant_id into v_tenant_id;
    end if;

    select branch_id into v_branch_id from general_schema.branch where tenant_id = v_tenant_id and branch_name = 'Main Store' limit 1;
    if v_branch_id is null then
        INSERT INTO general_schema.branch (tenant_id, branch_name, branch_address, is_main_branch)
        VALUES (v_tenant_id, 'Main Store', 'Test Address 1', true)
        returning branch_id into v_branch_id;
    end if;

    select user_id into v_user_id from general_schema.users where tenant_id = v_tenant_id and email = 'cashier@returntest.com' limit 1;
    if v_user_id is null then
        INSERT INTO general_schema.users (tenant_id, email, password_hash, role_id)
        VALUES (v_tenant_id, 'cashier@returntest.com', 'testhash', 1)
        returning user_id into v_user_id;
    end if;

    select tenant_customer_id into v_customer_id from general_schema.tenant_customer where tenant_id = v_tenant_id and email = 'customer@returntest.com' limit 1;
    if v_customer_id is null then
        INSERT INTO general_schema.tenant_customer (tenant_id, first_name, last_name, document_number, email, phone)
        VALUES (v_tenant_id, 'Alice', 'Return', 'RT-001', 'customer@returntest.com', '555-0001')
        returning tenant_customer_id into v_customer_id;
    end if;

    INSERT INTO general_schema.product (cabys_code, product_name)
    VALUES ('RTTEST0000001', 'Productos de prueba devoluciones')
    ON CONFLICT (cabys_code) DO NOTHING;

    -- Crear tasa de impuesto 10% y asignar al producto
    INSERT INTO general_schema.tax_rate (rate_percentage, rate_code, rate_name)
    VALUES (10.00, 'I-10-TEST', 'IVA 10% (Test Devoluciones)')
    RETURNING tax_rate_id INTO v_tax_rate_id;

    UPDATE general_schema.product SET tax_rate_id = v_tax_rate_id
    WHERE cabys_code = 'RTTEST0000001';

    raise notice '✅ Tasa IVA 10%% asignada a producto (tax_rate_id: %)', v_tax_rate_id;

    select product_variant_id into v_prod_a from general_schema.product_variant where tenant_id = v_tenant_id and sku = 'RT-A' limit 1;
    if v_prod_a is null then
        INSERT INTO general_schema.product_variant (tenant_id, cabys_code, sku, variant_name, unit_price, is_active)
        VALUES (v_tenant_id, 'RTTEST0000001', 'RT-A', 'Producto A', 100.00, true)
        returning product_variant_id into v_prod_a;
    end if;

    select product_variant_id into v_prod_b from general_schema.product_variant where tenant_id = v_tenant_id and sku = 'RT-B' limit 1;
    if v_prod_b is null then
        INSERT INTO general_schema.product_variant (tenant_id, cabys_code, sku, variant_name, unit_price, is_active)
        VALUES (v_tenant_id, 'RTTEST0000001', 'RT-B', 'Producto B', 200.00, true)
        returning product_variant_id into v_prod_b;
    end if;

    select product_variant_id into v_prod_c from general_schema.product_variant where tenant_id = v_tenant_id and sku = 'RT-C' limit 1;
    if v_prod_c is null then
        INSERT INTO general_schema.product_variant (tenant_id, cabys_code, sku, variant_name, unit_price, is_active)
        VALUES (v_tenant_id, 'RTTEST0000001', 'RT-C', 'Producto C', 50.00, true)
        returning product_variant_id into v_prod_c;
    end if;

    select cash_register_id into v_cash_reg from pos_schema.cash_register where branch_id = v_branch_id limit 1;
    if v_cash_reg is null then
        INSERT INTO pos_schema.cash_register (branch_id, is_active) VALUES (v_branch_id, true) returning cash_register_id into v_cash_reg;
    end if;

    perform 1 from pos_schema.cash_register_session where cash_register_id = v_cash_reg and is_active = true;
    if not found then
        INSERT INTO pos_schema.cash_register_session (cash_register_id, user_id, opening_amount, is_active)
        VALUES (v_cash_reg, v_user_id, 100.00, true);
    end if;

    perform 1 from general_schema.payment_method where payment_method_id = 1;
    if not found then
        INSERT INTO general_schema.payment_method(name) VALUES ('cash');
    end if;
    perform 1 from general_schema.payment_method where payment_method_id = 4;
    if not found then
        INSERT INTO general_schema.payment_method(name) VALUES ('loyalty_points');
    end if;

    raise notice '✅ SECCIÓN 1 COMPLETADA';
    raise notice '========================================';
end $$;


-- ========================================
-- SECCIÓN 2: Crear venta y pagar (genera factura digital)
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_branch_id uuid;
    v_customer_id uuid;
    v_prod_a uuid;
    v_prod_b uuid;
    v_prod_c uuid;
    v_sale_id uuid;
    v_payment_id uuid;
    v_tax numeric(10,2);
    v_subtotal numeric(10,2);
    v_total numeric(10,2);
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '🛒 SECCIÓN 2: Crear venta y pagar (genera factura)';
    raise notice '========================================';

    select tenant_id into v_tenant_id from general_schema.tenant where tenant_name = 'Return Test Shop' limit 1;
    select branch_id into v_branch_id from general_schema.branch where tenant_id = v_tenant_id and branch_name = 'Main Store' limit 1;
    select tenant_customer_id into v_customer_id from general_schema.tenant_customer where tenant_id = v_tenant_id and email = 'customer@returntest.com' limit 1;
    select product_variant_id into v_prod_a from general_schema.product_variant where tenant_id = v_tenant_id and sku = 'RT-A' limit 1;
    select product_variant_id into v_prod_b from general_schema.product_variant where tenant_id = v_tenant_id and sku = 'RT-B' limit 1;
    select product_variant_id into v_prod_c from general_schema.product_variant where tenant_id = v_tenant_id and sku = 'RT-C' limit 1;

    v_subtotal := 140.00; -- A x5 (50) + B x3 (60) + C x2 (30)
    -- Tax is computed per-item by create_digital_sale_invoice trigger from product -> tax_rate
    -- For the sale itself, we set 10% to match the product's tax_rate (IVA-10-TEST-RT)
    v_tax := round(v_subtotal * 0.10, 2); -- 10% matching product tax_rate
    v_total := v_subtotal + v_tax;

    INSERT INTO pos_schema.sale (branch_id, currency_id, subtotal_amount, tax_amount, total_amount, is_completed)
    VALUES (v_branch_id, 1, v_subtotal, v_tax, v_total, false)
    returning sale_id into v_sale_id;

    INSERT INTO pos_schema.sale_item (sale_id, tenant_id, product_variant_id, quantity, unit_price, total_price)
    VALUES 
        (v_sale_id, v_tenant_id, v_prod_a, 5, 10.00, 50.00),
        (v_sale_id, v_tenant_id, v_prod_b, 3, 20.00, 60.00),
        (v_sale_id, v_tenant_id, v_prod_c, 2, 15.00, 30.00);

    raise notice '✓ Sale created: % (subtotal $% tax $% total $%)', v_sale_id, v_subtotal, v_tax, v_total;

    INSERT INTO pos_schema.customer_payment (tenant_customer_id, sale_id, payment_method_id, payment_amount, currency_id, verified)
    VALUES (v_customer_id, v_sale_id, 1, v_total, 1, false)
    returning customer_payment_id into v_payment_id;

    raise notice '✓ Payment created (unverified): % amount $%', v_payment_id, v_total;

    call pos_schema.verify_customer_payment(v_payment_id);

    perform pg_sleep(0.2);

    if not exists (select 1 from pos_schema.digital_sale_invoice where sale_id = v_sale_id) then
        raise exception 'Digital sale invoice was not created for sale %', v_sale_id;
    end if;

    raise notice '✅ SECCIÓN 2 COMPLETADA - Sale invoiced';
end $$;


-- ========================================
-- SECCIÓN 3: Devolución PARCIAL (menos que lo comprado)
-- ========================================
DO $$
declare
    v_sale_id uuid;
    v_digital_sale_invoice_id uuid;
    v_return_tx uuid;
    v_customer_id uuid;
    v_si_a uuid;
    v_si_b uuid;
    v_return_total numeric(10,2);
    v_expected_return numeric(10,2) := 40.00;
    v_return_product_count int;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '🔄 SECCIÓN 3: Crear devolución PARCIAL';
    raise notice '========================================';

    select s.sale_id into v_sale_id
    from pos_schema.sale s
    join general_schema.branch b on s.branch_id = b.branch_id
    join general_schema.tenant t on b.tenant_id = t.tenant_id
    where t.tenant_name = 'Return Test Shop'
    order by s.sale_date desc
    limit 1;

    if v_sale_id is null then raise exception 'No sale found for partial return'; end if;

    select digital_sale_invoice_id, tenant_customer_id into v_digital_sale_invoice_id, v_customer_id from pos_schema.digital_sale_invoice where sale_id = v_sale_id limit 1;

    select sale_item_id into v_si_a from pos_schema.sale_item where sale_id = v_sale_id and product_variant_id = (
        select product_variant_id from general_schema.product_variant where tenant_id = (select tenant_id from general_schema.tenant where tenant_name = 'Return Test Shop' limit 1) and sku = 'RT-A' limit 1
    ) limit 1;

    select sale_item_id into v_si_b from pos_schema.sale_item where sale_id = v_sale_id and product_variant_id = (
        select product_variant_id from general_schema.product_variant where tenant_id = (select tenant_id from general_schema.tenant where tenant_name = 'Return Test Shop' limit 1) and sku = 'RT-B' limit 1
    ) limit 1;

    if v_si_a is null or v_si_b is null then
        raise exception 'Sale items for A or B not found';
    end if;

    INSERT INTO pos_schema.return_transaction (digital_sale_invoice_id, tenant_customer_id, total_refund_amount, refund_method, return_status_id)
    VALUES (v_digital_sale_invoice_id, v_customer_id, 0.00, 1, (select return_status_id from pos_schema.return_status where status_name = 'pending' limit 1))
    returning return_transaction_id into v_return_tx;

    raise notice '✓ Return transaction created: %', v_return_tx;

    -- insert return lines (trigger will compute total_price and update sale_item/digital_sale_invoice)
    INSERT INTO pos_schema.return_product (return_transaction_id, sale_item_id, quantity, unit_price)
    VALUES
        (v_return_tx, v_si_a, 2, 10.00),
        (v_return_tx, v_si_b, 1, 20.00);

    perform pg_sleep(0.1);

    -- Verify return_product rows were created
    select count(*) into v_return_product_count from pos_schema.return_product where return_transaction_id = v_return_tx;
    
    if v_return_product_count <> 2 then
        raise exception 'Expected 2 return_product rows, found %', v_return_product_count;
    end if;

    raise notice '✓ return_product rows created: %', v_return_product_count;

    select coalesce(sum(total_price),0) into v_return_total from pos_schema.return_product where return_transaction_id = v_return_tx;

    if abs(v_return_total - v_expected_return) > 0.01 then
        raise exception 'Partial return recorded amount mismatch. Expected $% got $%', v_expected_return, v_return_total;
    end if;

    update pos_schema.return_transaction set total_refund_amount = v_return_total where return_transaction_id = v_return_tx;

    raise notice '✓ Partial return recorded: % lines, returned total $%', v_return_product_count, v_return_total;
    raise notice '✅ SECCIÓN 3 COMPLETADA';
end $$;


-- ========================================
-- SECCIÓN 4: Verificaciones después de devolución PARCIAL
-- ========================================
DO $$
declare
    v_invoice record;
    v_qty_a int;
    v_qty_b int;
    v_qty_c int;
    v_tenant_id uuid;
    v_tax_rate numeric(5,2);
    v_expected_subtotal numeric(10,2) := 100.00; -- 140 - 40
    v_expected_tax numeric(10,2);
    v_expected_total numeric(10,2);
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '📦 SECCIÓN 4: Verificaciones tras devolución PARCIAL';
    raise notice '========================================';

    select tenant_id into v_tenant_id from general_schema.tenant where tenant_name = 'Return Test Shop' limit 1;

    select b.subtotal_amount, b.tax_amount, b.total_amount into v_invoice
    from pos_schema.digital_sale_invoice b
    join pos_schema.sale s on b.sale_id = s.sale_id
    join general_schema.branch br on s.branch_id = br.branch_id
    where br.tenant_id = v_tenant_id
    order by b.invoiced_at desc
    limit 1;

    select coalesce(quantity,0) into v_qty_a from pos_schema.sale_item si join general_schema.product_variant pv on si.tenant_id = pv.tenant_id and si.product_variant_id = pv.product_variant_id where pv.sku = 'RT-A' and si.tenant_id = v_tenant_id limit 1;
    select coalesce(quantity,0) into v_qty_b from pos_schema.sale_item si join general_schema.product_variant pv on si.tenant_id = pv.tenant_id and si.product_variant_id = pv.product_variant_id where pv.sku = 'RT-B' and si.tenant_id = v_tenant_id limit 1;
    select coalesce(quantity,0) into v_qty_c from pos_schema.sale_item si join general_schema.product_variant pv on si.tenant_id = pv.tenant_id and si.product_variant_id = pv.product_variant_id where pv.sku = 'RT-C' and si.tenant_id = v_tenant_id limit 1;

    -- Per-item tax: get from product's tax_rate (set in Section 1 as 10%)
    select tr.rate_percentage into v_tax_rate
    from general_schema.product p
    join general_schema.tax_rate tr on p.tax_rate_id = tr.tax_rate_id
    where p.cabys_code = 'RTTEST0000001'
    limit 1;

    if v_tax_rate is null then v_tax_rate := 0; end if;

    v_expected_tax := round(v_expected_subtotal * (v_tax_rate / 100), 2);
    v_expected_total := round(v_expected_subtotal + v_expected_tax, 2);

    raise notice 'Invoice after partial return: subtotal $% tax $% total $%', v_invoice.subtotal_amount, v_invoice.tax_amount, v_invoice.total_amount;
    raise notice 'Remaining quantities -> A: %, B: %, C: %', v_qty_a, v_qty_b, v_qty_c;

    if abs(v_invoice.subtotal_amount - v_expected_subtotal) > 0.01 then
        raise exception 'Partial return: Invoice subtotal mismatch. Expected $% got $%', v_expected_subtotal, v_invoice.subtotal_amount;
    end if;

    if abs(v_invoice.tax_amount - v_expected_tax) > 0.01 then
        raise exception 'Partial return: Invoice tax mismatch. Expected $% got $%', v_expected_tax, v_invoice.tax_amount;
    end if;

    if abs(v_invoice.total_amount - v_expected_total) > 0.01 then
        raise exception 'Partial return: Invoice total mismatch. Expected $% got $%', v_expected_total, v_invoice.total_amount;
    end if;

    -- verify sale totals reconciled with remaining sale_items
    raise notice '✅ SECCIÓN 4 COMPLETADA - Partial return verified';
end $$;


-- ========================================
-- SECCIÓN 5: Devolución TOTAL de los elementos restantes
-- ========================================
DO $$
declare
    v_digital_sale_invoice_id uuid;
    v_return_tx uuid;
    v_sale_id uuid;
    v_customer_id uuid;
    v_si record;
    v_total_returned numeric(10,2) := 0;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '🔄 SECCIÓN 5: Devolución TOTAL de elementos restantes';
    raise notice '========================================';

    select s.sale_id into v_sale_id
    from pos_schema.sale s
    join general_schema.branch b on s.branch_id = b.branch_id
    join general_schema.tenant t on b.tenant_id = t.tenant_id
    where t.tenant_name = 'Return Test Shop'
    order by s.sale_date desc
    limit 1;

    select digital_sale_invoice_id, tenant_customer_id into v_digital_sale_invoice_id, v_customer_id from pos_schema.digital_sale_invoice where sale_id = v_sale_id limit 1;

    INSERT INTO pos_schema.return_transaction (digital_sale_invoice_id, tenant_customer_id, total_refund_amount, refund_method, return_status_id)
    VALUES (v_digital_sale_invoice_id, v_customer_id, 0.00, 1, (select return_status_id from pos_schema.return_status where status_name = 'pending' limit 1))
    returning return_transaction_id into v_return_tx;

    for v_si in
        select sale_item_id, quantity, unit_price from pos_schema.sale_item where sale_id = v_sale_id
    loop
        v_total_returned := v_total_returned + (v_si.quantity * v_si.unit_price);
        INSERT INTO pos_schema.return_product (return_transaction_id, sale_item_id, quantity, unit_price)
        VALUES (v_return_tx, v_si.sale_item_id, v_si.quantity, v_si.unit_price);
    end loop;

    update pos_schema.return_transaction set total_refund_amount = v_total_returned where return_transaction_id = v_return_tx;

    perform pg_sleep(0.1);

    raise notice '✓ Total return created: % , refunded $%', v_return_tx, v_total_returned;
    raise notice '✅ SECCIÓN 5 COMPLETADA';
end $$;


-- ========================================
-- SECCIÓN 6: Verificaciones después de devolución TOTAL
-- ========================================
DO $$
declare
    v_invoice record;
    v_remaining_items int;
    v_tenant_id uuid;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '📦 SECCIÓN 6: Verificaciones tras devolución TOTAL';
    raise notice '========================================';

    select tenant_id into v_tenant_id from general_schema.tenant where tenant_name = 'Return Test Shop' limit 1;

    select b.subtotal_amount, b.tax_amount, b.total_amount into v_invoice
    from pos_schema.digital_sale_invoice b
    join pos_schema.sale s on b.sale_id = s.sale_id
    join general_schema.branch br on s.branch_id = br.branch_id
    where br.tenant_id = v_tenant_id
    order by b.invoiced_at desc
    limit 1;

    select count(*) into v_remaining_items from pos_schema.sale_item si
    join pos_schema.sale s on si.sale_id = s.sale_id
    join general_schema.branch br on s.branch_id = br.branch_id
    where br.tenant_id = v_tenant_id;

    raise notice 'Invoice after total return: subtotal $% tax $% total $%', v_invoice.subtotal_amount, v_invoice.tax_amount, v_invoice.total_amount;
    raise notice 'Remaining sale_item rows for tenant: %', v_remaining_items;

    if v_remaining_items <> 0 then
        raise exception 'Total return failed: sale_items still exist (% rows)', v_remaining_items;
    end if;

    if round(v_invoice.subtotal_amount,2) <> 0.00 or round(v_invoice.total_amount,2) <> 0.00 then
        raise exception 'Total return failed: Invoice not zeroed (subtotal $% total $%)', v_invoice.subtotal_amount, v_invoice.total_amount;
    end if;

    raise notice '✅ Total return succeeded, invoice zeroed and sale items removed';
    raise notice '✅ SECCIÓN 6 COMPLETADA';
end $$;


-- ========================================
-- SECCIÓN 7: Resumen final
-- ========================================
DO $$
declare
    v_tenant_id uuid;
    v_customer_id uuid;
    v_return_count int;
    v_return_sum numeric(10,2);
    v_return_detail record;
BEGIN
    raise notice '';
    raise notice '========================================';
    raise notice '📊 SECCIÓN 7: RESUMEN FINAL';
    raise notice '========================================';

    select tenant_id into v_tenant_id from general_schema.tenant where tenant_name = 'Return Test Shop' limit 1;
    select tenant_customer_id into v_customer_id from general_schema.tenant_customer where tenant_id = v_tenant_id limit 1;

    select count(rp.return_product_id), coalesce(sum(rp.total_price),0)
    into v_return_count, v_return_sum
    from pos_schema.return_product rp
    join pos_schema.return_transaction rt on rp.return_transaction_id = rt.return_transaction_id
    join pos_schema.digital_sale_invoice b on rt.digital_sale_invoice_id = b.digital_sale_invoice_id
    where b.sale_id in (
        select s.sale_id from pos_schema.sale s
        join general_schema.branch br on s.branch_id = br.branch_id
        where br.tenant_id = v_tenant_id
    );

    raise notice 'Tenant: %', v_tenant_id;
    raise notice 'Customer: %', v_customer_id;
    raise notice 'Total return_product lines: %', v_return_count;
    raise notice 'Total returned amount: $%', v_return_sum;
    raise notice '';
    
    -- Show detailed return_product entries
    raise notice '📋 DETALLE DE DEVOLUCIONES (return_product):';
    for v_return_detail in
        select 
            rp.return_product_id,
            rp.quantity,
            rp.unit_price,
            rp.total_price,
            pv.sku,
            pv.variant_name
        from pos_schema.return_product rp
        join pos_schema.return_transaction rt on rp.return_transaction_id = rt.return_transaction_id
        join pos_schema.digital_sale_invoice b on rt.digital_sale_invoice_id = b.digital_sale_invoice_id
        join pos_schema.sale_item si on rp.sale_item_id = si.sale_item_id
        join general_schema.product_variant pv on si.product_variant_id = pv.product_variant_id and si.tenant_id = pv.tenant_id
        where b.sale_id in (
            select s.sale_id from pos_schema.sale s
            join general_schema.branch br on s.branch_id = br.branch_id
            where br.tenant_id = v_tenant_id
        )
    loop
        raise notice '  - % (%) × % @ $% = $%',
            v_return_detail.variant_name,
            v_return_detail.sku,
            v_return_detail.quantity,
            v_return_detail.unit_price,
            v_return_detail.total_price;
    end loop;
    
    raise notice '';
    raise notice '✅ TEST COMPLETO - Partial & Total returns flow validated';
    raise notice '========================================';
end $$;