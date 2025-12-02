create or replace function calculate_supply_order_total(
    p_supply_order_id uuid
) returns numeric as $$
declare
    v_total numeric(12,3);
begin
    select coalesce(sum(quantity_ordered * unit_price), 0)
    into v_total
    from supplies_module.supply_order_item
    where supply_order_id = p_supply_order_id;

    return round(v_total::numeric, 3);
end;
$$ language plpgsql;

create or replace function create_supply_order(
    p_supplier_id uuid,
    p_warehouse_id uuid,
    p_expected_delivery_date date,
    p_items jsonb default '[]'::jsonb    
) returns uuid as $$
declare
    v_supply_order_id uuid;
    v_item jsonb;
    v_tenant_id uuid;
    v_product_id uuid;
    v_qty integer;
    v_unit numeric(12,3);
    v_total numeric(12,3);
begin

    select b.tenant_id into v_tenant_id
    from supplies_module.supplier s
    join core.branch b on b.branch_id = s.branch_id
    where s.supplier_id = p_supplier_id;

    if v_tenant_id is null then
        raise exception 'Cannot determine tenant_id for supplier %', p_supplier_id;
    end if;

    insert into supplies_module.supply_order(
        supplier_id,
        warehouse_id,
        expected_delivery_date,
        supply_order_status_id
    ) values (
        p_supplier_id,
        p_warehouse_id,
        p_expected_delivery_date,
        1
    ) returning supply_order_id into v_supply_order_id;

    if p_items is not null and jsonb_typeof(p_items) = 'array' and jsonb_array_length(p_items) > 0 then
        for v_item in select * from jsonb_array_elements(p_items)
        loop
            v_product_id := (v_item ->> 'product_id')::uuid;
            v_qty := coalesce((v_item ->> 'quantity_ordered')::int, 0);
            v_unit := coalesce((v_item ->> 'unit_price')::numeric, 0);

            insert into supplies_module.supply_order_item(
                supply_order_id,
                tenant_id,
                product_id,
                quantity_ordered,
                unit_price
            ) values (
                v_supply_order_id,
                v_tenant_id,
                v_product_id,
                v_qty,
                v_unit
            );
        end loop;
    end if;

    v_total := coalesce(supplies_module.calculate_supply_order_total(v_supply_order_id), 0);

    insert into supplies_module.account_payable(
        account_payable_id,
        supply_order_id,
        amount_due,
        due_date,
        account_status,
        created_at,
        updated_at
    ) values (
        gen_random_uuid(),
        v_supply_order_id,
        v_total,
        (current_date + interval '30 days')::date,
        1,
        current_timestamp,
        current_timestamp
    )
    on conflict (supply_order_id) do update
    set amount_due = excluded.amount_due,
        due_date = excluded.due_date,
        account_status = excluded.account_status,
        updated_at = current_timestamp;

    return v_supply_order_id;
end;
$$ language plpgsql;

create or replace function update_order_status()
returns trigger as $$
begin
    insert into supplies_module.supply_order_tracking(
        supply_order_id,
        previous_status_id,
        new_status_id,
        notes,
        changed_at
    ) values (
        coalesce(new.supply_order_id, old.supply_order_id),
        old.supply_order_status_id,
        new.supply_order_status_id,
        'Status updated via trigger',
        current_timestamp
    );

    update supplies_module.supply_order
    set supply_order_status_id = new.supply_order_status_id,
        updated_at = current_timestamp
    where supply_order_id = coalesce(new.supply_order_id, old.supply_order_id);

    return new;
end;
$$ language plpgsql;
drop trigger if exists on_order_status_insert on supplies_module.supply_order;
create trigger on_order_status_insert
after update of supply_order_status_id on supplies_module.supply_order
for each row execute function update_order_status();

create or replace function check_account_payable_completion(
    _account_payable_id uuid
) returns boolean as $$
declare
    _amount_due numeric(12,3);
    _payments_total numeric(12,3);
    _pending_payments int;
    _current_status int;
begin
    select amount_due, account_status
    into _amount_due, _current_status
    from supplies_module.account_payable
    where account_payable_id = _account_payable_id;
    
    if _amount_due is null then
        raise exception 'Account payable not found: %', _account_payable_id;
    end if;
    
    select count(*) into _pending_payments
    from supplies_module.supply_order_payment
    where account_payable_id = _account_payable_id
    and verified = false;
    
    if _pending_payments > 0 then
        raise notice '   ⏳ Account % has % unverified payments', _account_payable_id, _pending_payments;
        return false;
    end if;
    
    select coalesce(sum(amount_paid), 0) into _payments_total
    from supplies_module.supply_order_payment
    where account_payable_id = _account_payable_id
    and verified = true;
    
    raise notice '   💰 Amount due: $%', _amount_due;
    raise notice '   💳 Payments total: $%', _payments_total;
    raise notice '   📊 Balance: $%', (_amount_due - _payments_total);
    
    if abs(_payments_total - _amount_due) <= 0.01 then
        update supplies_module.account_payable
        set amount_paid = _payments_total,
            account_status = 3,  
            updated_at = current_timestamp
        where account_payable_id = _account_payable_id;
        
        raise notice '   ✅ Account % marked as PAID', _account_payable_id;
        return true;
        
    elsif _payments_total > _amount_due then
        raise warning 'Overpayment detected: Expected $%, Paid $%', _amount_due, _payments_total;
        
        update supplies_module.account_payable
        set amount_paid = _payments_total,
            account_status = 3,  
            updated_at = current_timestamp
        where account_payable_id = _account_payable_id;
        
        return true;
        
    elsif _payments_total > 0 then
        update supplies_module.account_payable
        set amount_paid = _payments_total,
            account_status = 2,  
            updated_at = current_timestamp
        where account_payable_id = _account_payable_id;
        
        raise notice '   ⏳ Account % partially paid (shortage: $%)', 
            _account_payable_id, (_amount_due - _payments_total);
        return false;
    else
        raise notice '   ⏳ Account % still pending (no payments)', _account_payable_id;
        return false;
    end if;
    
exception
    when others then
        raise notice '   ❌ Error checking account completion: %', sqlerrm;
        return false;
end;
$$ language plpgsql;

create or replace procedure supplies_module.verify_supply_order_payment(
    _payment_id uuid
) as $$
declare
    _exists boolean;
    _already_verified boolean;
    _account_payable_id uuid;
    _amount_paid numeric(10,2);
    _payment_method varchar(50);
    _account_completed boolean;
begin
    select exists(
        select 1 
        from supplies_module.supply_order_payment
        where payment_id = _payment_id
    ) into _exists;
    
    if not _exists then
        raise exception 'Payment not found: %', _payment_id;
    end if;
    
    select verified, account_payable_id, amount_paid
    into _already_verified, _account_payable_id, _amount_paid
    from supplies_module.supply_order_payment
    where payment_id = _payment_id;
    
    if _already_verified then
        raise notice '⚠️  Payment % is already verified', _payment_id;
        return;
    end if;

    select pm.name into _payment_method
    from core.payment_method pm
    join supplies_module.supply_order_payment sop on pm.payment_method_id = sop.payment_method_id
    where sop.payment_id = _payment_id;
    
    update supplies_module.supply_order_payment
    set verified = true,
        updated_at = current_timestamp
    where payment_id = _payment_id;
    
    raise notice '✅ Payment verified successfully';
    raise notice '';
    
    raise notice '🔍 Checking if account is fully paid...';
    _account_completed := supplies_module.check_account_payable_completion(_account_payable_id);
    
    if _account_completed then
        raise notice '';
        raise notice '🎉 Account % is FULLY PAID', _account_payable_id;
    else
        raise notice '';
        raise notice '⏳ Account % still has pending balance', _account_payable_id;
    end if;
    
exception
    when others then
        raise notice '❌ Payment verification failed: %', sqlerrm;
        raise;
end;
$$ language plpgsql;

create or replace function recalc_account_payable_on_payment()
returns trigger as $$
declare
    _account_payable_id uuid;
begin
    _account_payable_id := coalesce(new.account_payable_id, old.account_payable_id);
    
    perform supplies_module.check_account_payable_completion(_account_payable_id);
    
    return coalesce(new, old);
end;
$$ language plpgsql;

drop trigger if exists recalc_account_payable_on_payment_trigger on supplies_module.supply_order_payment;
create trigger recalc_account_payable_on_payment_trigger
    after insert or update of verified or delete on supplies_module.supply_order_payment
    for each row
    execute function supplies_module.recalc_account_payable_on_payment();

create or replace function create_supplier_invoice()
returns trigger as $$
declare
    v_supplier_invoice_id uuid;
    v_supply_order_id uuid;
    v_supplier_id uuid;
    v_branch_id uuid;
    v_tenant_id uuid;
    v_region_id int;
    v_rate_pct numeric;
    v_tax_rate numeric := 0.13; -- default fallback 13%
    v_subtotal numeric(12,3);
    v_tax_amount numeric(12,3);
    v_item record;
begin

    select supply_order_id into v_supply_order_id
    from supplies_module.account_payable
    where account_payable_id = new.account_payable_id;

    if v_supply_order_id is null then
        raise notice 'No supply_order found for account_payable %', new.account_payable_id;
        return new;
    end if;

    select supplier_id into v_supplier_id
    from supplies_module.supply_order
    where supply_order_id = v_supply_order_id;

    if v_supplier_id is null then
        raise notice 'No supplier found for supply_order %', v_supply_order_id;
        return new;
    end if;

    select branch_id into v_branch_id
    from supplies_module.supplier
    where supplier_id = v_supplier_id;

    if v_branch_id is not null then
        select tenant_id into v_tenant_id
        from core.branch
        where branch_id = v_branch_id;
    end if;

    if v_tenant_id is not null then
        select region_id into v_region_id
        from core.tenant
        where tenant_id = v_tenant_id;
    end if;

    if v_region_id is not null then
        select rate_percentage into v_rate_pct
        from core.tax_rate
        where region_id = v_region_id
        limit 1;
    end if;

    if v_rate_pct is not null then
        v_tax_rate := (v_rate_pct::numeric / 100.0);
    else
        select rate_percentage into v_rate_pct
        from core.tax_rate
        where region_id is null
        limit 1;

        if v_rate_pct is not null then
            v_tax_rate := (v_rate_pct::numeric / 100.0);
        else
            v_tax_rate := 0.13;
        end if;
    end if;

    if exists(
        select 1 
        from supplies_module.supplier_invoice 
        where supply_order_id = v_supply_order_id
    ) then
        raise notice '⚠️  Supplier invoice already exists for supply order %', v_supply_order_id;
        return new;
    end if;

    v_subtotal := new.amount_due / (1 + v_tax_rate);
    v_tax_amount := new.amount_due - v_subtotal;

    insert into supplies_module.supplier_invoice(
        supplier_invoice_id,
        supply_order_id,
        invoice_number,
        invoice_date,
        due_date,
        subtotal_amount,
        tax_amount,
        created_at,
        updated_at
    ) values (
        gen_random_uuid(),
        v_supply_order_id,
        'INV-' || to_char(current_timestamp, 'YYYYMMDD-HH24MISS') || '-' || substring(v_supply_order_id::text, 1, 8),
        current_timestamp,
        new.due_date,
        round(v_subtotal, 3),
        round(v_tax_amount, 3),
        current_timestamp,
        current_timestamp
    ) returning supplier_invoice_id into v_supplier_invoice_id;

    raise notice '✅ Created supplier invoice % for supply order %', v_supplier_invoice_id, v_supply_order_id;

    for v_item in 
        select tenant_id, product_id, quantity_ordered, unit_price
        from supplies_module.supply_order_item
        where supply_order_id = v_supply_order_id
    loop
        insert into supplies_module.supplier_invoice_item(
            supplier_invoice_item_id,
            supplier_invoice_id,
            tenant_id,           
            product_id,
            quantity_billed,
            unit_price,
            created_at,
            updated_at
        ) values (
            gen_random_uuid(),
            v_supplier_invoice_id,
            v_item.tenant_id,    
            v_item.product_id,
            v_item.quantity_ordered,
            v_item.unit_price,
            current_timestamp,
            current_timestamp
        );
    end loop;

    raise notice '✅ Copied % items to supplier invoice', (
        select count(*) 
        from supplies_module.supplier_invoice_item 
        where supplier_invoice_id = v_supplier_invoice_id
    );

    return new;
end;
$$ language plpgsql;

drop trigger if exists create_supplier_invoice on supplies_module.account_payable;
create trigger create_supplier_invoice
    after update of account_status on supplies_module.account_payable
    for each row
    when (new.account_status = 3 and old.account_status is distinct from 3)
    execute function supplies_module.create_supplier_invoice();

-- create or replace function create_goods_receipt()
-- returns trigger as $$
-- declare
--     v_goods_receipt_id uuid;
--     v_supply_order_id uuid;
--     v_item record;
-- begin
-- end
-- $$ language plpgsql;

-- drop trigger if exists create_goods_receipt on supplies_module.supply_order;
-- create trigger create_goods_receipt
--     after update of supply_order_status_id on supplies_module.supply_order
--     for each row
--     when (new.supply_order_status_id = 4 and old.supply_order_status_id is distinct from 4)
--     execute function supplies_module.create_goods_receipt();

-- create or replace function payment_alert_check()


-- Update timestamp triggers

drop trigger if exists update_supplier_timestamp on supplies_module.supplier;
create trigger update_supplier_timestamp before update on supplies_module.supplier
for each row execute function core.update_timestamp();

drop trigger if exists update_supply_order_timestamp on supplies_module.supply_order;
create trigger update_supply_order_timestamp before update on supplies_module.supply_order
for each row execute function core.update_timestamp();

drop trigger if exists update_supply_order_item_timestamp on supplies_module.supply_order_item;
create trigger update_supply_order_item_timestamp before update on supplies_module.supply_order_item
for each row execute function core.update_timestamp();

drop trigger if exists update_supplier_invoice_timestamp on supplies_module.supplier_invoice;
create trigger update_supplier_invoice_timestamp before update on supplies_module.supplier_invoice
for each row execute function core.update_timestamp();

drop trigger if exists update_supplier_invoice_item_timestamp on supplies_module.supplier_invoice_item;
create trigger update_supplier_invoice_item_timestamp before update on supplies_module.supplier_invoice_item
for each row execute function core.update_timestamp();

drop trigger if exists update_goods_receipt_timestamp on supplies_module.goods_receipt;
create trigger update_goods_receipt_timestamp before update on supplies_module.goods_receipt
for each row execute function core.update_timestamp();

drop trigger if exists update_goods_receipt_item_timestamp on supplies_module.goods_receipt_item;
create trigger update_goods_receipt_item_timestamp before update on supplies_module.goods_receipt_item
for each row execute function core.update_timestamp();

drop trigger if exists update_account_payable_timestamp on supplies_module.account_payable;
create trigger update_account_payable_timestamp before update on supplies_module.account_payable
for each row execute function core.update_timestamp();

drop trigger if exists update_supply_order_payment_timestamp on supplies_module.supply_order_payment;
create trigger update_supply_order_payment_timestamp before update on supplies_module.supply_order_payment
for each row execute function core.update_timestamp();

drop trigger if exists update_supply_order_payment_alert_timestamp on supplies_module.supply_order_payment_alert;
create trigger update_supply_order_payment_alert_timestamp before update on supplies_module.supply_order_payment_alert
for each row execute function core.update_timestamp();

drop trigger if exists update_supply_order_payment_alert_config_timestamp on supplies_module.supply_order_payment_alert_config;
create trigger update_supply_order_payment_alert_config_timestamp before update on supplies_module.supply_order_payment_alert_config
for each row execute function core.update_timestamp();

-- drop trigger if exists update_three_way_matching_timestamp on supplies_module.three_way_matching;
-- create trigger update_three_way_matching_timestamp before update on supplies_module.three_way_matching
-- for each row execute function core.update_timestamp();