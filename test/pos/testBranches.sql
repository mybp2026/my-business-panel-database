-- =====================================
-- TEST: Ventas en varias sucursales y reportes
-- =====================================

-- SECCIÓN 0: Limpieza inicial de datos de prueba
do $$
begin
    -- Elimina ventas y sus items
    delete from pos_module.sale_item
    where sale_id in (
        select sale_id from pos_module.sale
        where branch_id in (
            select branch_id from general.branch
            where tenant_id in (
                select tenant_id from general.tenant
                where tenant_name = 'Comercio MultiSucursal'
            )
        )
    );

    delete from pos_module.sale
    where branch_id in (
        select branch_id from general.branch
        where tenant_id in (
            select tenant_id from general.tenant
            where tenant_name = 'Comercio MultiSucursal'
        )
    );

    -- Elimina productos
    delete from general.product
    where tenant_id in (
        select tenant_id from general.tenant
        where tenant_name = 'Comercio MultiSucursal'
    );

    -- Elimina cliente
    delete from general.tenant_customer
    where tenant_id in (
        select tenant_id from general.tenant
        where tenant_name = 'Comercio MultiSucursal'
    );

    -- Elimina usuario
    delete from general.users
    where tenant_id in (
        select tenant_id from general.tenant
        where tenant_name = 'Comercio MultiSucursal'
    );

    -- Elimina sucursales
    delete from general.branch
    where tenant_id in (
        select tenant_id from general.tenant
        where tenant_name = 'Comercio MultiSucursal'
    );

    -- Elimina tenant
    delete from general.tenant
    where tenant_name = 'Comercio MultiSucursal';

    raise notice '✓ Limpieza inicial completada';
end $$;

-- SECCIÓN 1: Setup inicial (tenants, sucursales, productos, clientes)
do $$
declare
    v_tenant_id uuid;
    v_branch_centro uuid;
    v_branch_norte uuid;
    v_user_id uuid;
    v_cliente_id uuid;
    v_prod_a uuid;
    v_prod_b uuid;
    v_prod_c uuid;
begin
    -- Crear tenant
    INSERT INTO general.tenant (tenant_name, region_id, contact_email, is_subscribed)
    VALUES ('Comercio MultiSucursal', 1, 'contacto@multi.com', true)
    returning tenant_id into v_tenant_id;

    -- Crear sucursales
    INSERT INTO general.branch (tenant_id, branch_name, branch_address, is_main_branch)
    VALUES (v_tenant_id, 'Sucursal Centro', 'Av. Central', true)
    returning branch_id into v_branch_centro;

    INSERT INTO general.branch (tenant_id, branch_name, branch_address, is_main_branch)
    VALUES (v_tenant_id, 'Sucursal Norte', 'Av. Norte', false)
    returning branch_id into v_branch_norte;

    -- Crear usuario cajero
    INSERT INTO general.users (tenant_id, email, password_hash, role_id)
    VALUES (v_tenant_id, 'cajero@multi.com', 'hash', 1)
    returning user_id into v_user_id;

    -- Crear cliente
    INSERT INTO general.tenant_customer (
        tenant_id, first_name, last_name, document_number,
        email, phone, customer_segment_id
    )
    VALUES (
        v_tenant_id, 'Ana', 'Ramírez', 'DNI-1111',
        'ana.ramirez@email.com', '+506-1111-2222', 1
    )
    returning tenant_customer_id into v_cliente_id;

    -- Crear productos
    INSERT INTO general.product (tenant_id, sku, product_name, unit_price)
    VALUES (v_tenant_id, 'PROD-A', 'Monitor LG', 200.00)
    returning product_id into v_prod_a;

    INSERT INTO general.product (tenant_id, sku, product_name, unit_price)
    VALUES (v_tenant_id, 'PROD-B', 'Mouse Genius', 20.00)
    returning product_id into v_prod_b;

    INSERT INTO general.product (tenant_id, sku, product_name, unit_price)
    VALUES (v_tenant_id, 'PROD-C', 'Teclado Redragon', 50.00)
    returning product_id into v_prod_c;

    raise notice '✓ Setup inicial completado';
end $$;

-- SECCIÓN 2: Realizar ventas en varias sucursales
do $$
declare
    v_tenant_id uuid;
    v_branch_centro uuid;
    v_branch_norte uuid;
    v_cliente_id uuid;
    v_prod_a uuid;
    v_prod_b uuid;
    v_prod_c uuid;
    v_sale_id uuid;
begin
    -- Obtener IDs
    select tenant_id into v_tenant_id from general.tenant where tenant_name = 'Comercio MultiSucursal';
    select branch_id into v_branch_centro from general.branch where tenant_id = v_tenant_id and branch_name = 'Sucursal Centro';
    select branch_id into v_branch_norte from general.branch where tenant_id = v_tenant_id and branch_name = 'Sucursal Norte';
    select tenant_customer_id into v_cliente_id from general.tenant_customer where tenant_id = v_tenant_id and email = 'ana.ramirez@email.com';
    select product_id into v_prod_a from general.product where tenant_id = v_tenant_id and sku = 'PROD-A';
    select product_id into v_prod_b from general.product where tenant_id = v_tenant_id and sku = 'PROD-B';
    select product_id into v_prod_c from general.product where tenant_id = v_tenant_id and sku = 'PROD-C';

    -- Venta 1 en Centro
    INSERT INTO pos_module.sale (branch_id, currency_id, subtotal_amount, tax_amount, total_amount, is_completed)
    VALUES (v_branch_centro, 1, 200.00, 26.00, 226.00, true)
    returning sale_id into v_sale_id;
    INSERT INTO pos_module.sale_item (sale_id, tenant_id, product_id, quantity, unit_price, total_price)
    VALUES (v_sale_id, v_tenant_id, v_prod_a, 1, 200.00, 200.00);

    -- Venta 2 en Centro
    INSERT INTO pos_module.sale (branch_id, currency_id, subtotal_amount, tax_amount, total_amount, is_completed)
    VALUES (v_branch_centro, 1, 70.00, 9.10, 79.10, true)
    returning sale_id into v_sale_id;
    INSERT INTO pos_module.sale_item (sale_id, tenant_id, product_id, quantity, unit_price, total_price)
    VALUES (v_sale_id, v_tenant_id, v_prod_b, 2, 20.00, 40.00);
    INSERT INTO pos_module.sale_item (sale_id, tenant_id, product_id, quantity, unit_price, total_price)
    VALUES (v_sale_id, v_tenant_id, v_prod_c, 1, 50.00, 50.00);

    -- Venta 3 en Norte
    INSERT INTO pos_module.sale (branch_id, currency_id, subtotal_amount, tax_amount, total_amount, is_completed)
    VALUES (v_branch_norte, 1, 100.00, 13.00, 113.00, true)
    returning sale_id into v_sale_id;
    INSERT INTO pos_module.sale_item (sale_id, tenant_id, product_id, quantity, unit_price, total_price)
    VALUES (v_sale_id, v_tenant_id, v_prod_c, 2, 50.00, 100.00);

    raise notice '✓ Ventas realizadas en ambas sucursales';
end $$;

-- SECCIÓN 3: Reporte - Ventas totales por sucursal
select 
    b.branch_name,
    count(s.sale_id) as ventas,
    sum(s.total_amount) as total_ventas
from pos_module.sale s
join general.branch b on s.branch_id = b.branch_id
join general.tenant t on b.tenant_id = t.tenant_id
where t.tenant_name = 'Comercio MultiSucursal'
group by b.branch_name
order by b.branch_name;

-- SECCIÓN 4: Reporte - Productos vendidos por sucursal
select 
    b.branch_name,
    p.product_name,
    sum(si.quantity) as cantidad_vendida,
    sum(si.total_price) as ingresos
from pos_module.sale_item si
join pos_module.sale s on si.sale_id = s.sale_id
join general.branch b on s.branch_id = b.branch_id
join general.product p on si.tenant_id = p.tenant_id and si.product_id = p.product_id
where b.branch_name in ('Sucursal Centro', 'Sucursal Norte')
group by b.branch_name, p.product_name
order by b.branch_name, ingresos desc;

-- SECCIÓN 5: Reporte - Ventas totales por producto (todas las sucursales)
select 
    p.product_name,
    sum(si.quantity) as cantidad_vendida,
    sum(si.total_price) as ingresos
from pos_module.sale_item si
join general.product p on si.tenant_id = p.tenant_id and si.product_id = p.product_id
group by p.product_name
order by ingresos desc;

-- SECCIÓN 6: Reporte - Detalle de ventas por sucursal
select 
    b.branch_name,
    s.sale_id,
    s.sale_date,
    s.total_amount,
    p.product_name,
    si.quantity,
    si.total_price
from pos_module.sale s
join general.branch b on s.branch_id = b.branch_id
join pos_module.sale_item si on s.sale_id = si.sale_id
join general.product p on si.tenant_id = p.tenant_id and si.product_id = p.product_id
where b.branch_name in ('Sucursal Centro', 'Sucursal Norte')
order by b.branch_name, s.sale_date desc;

