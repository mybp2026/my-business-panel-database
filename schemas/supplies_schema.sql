-- SCHEMA: supplies
drop schema if exists supplies_module cascade;
create schema if not exists supplies_module;
set search_path to supplies_module;

create table supplier(
    supplier_id uuid primary key default gen_random_uuid(),
    branch_id uuid not null references core.branch(branch_id) on delete cascade,
    supplier_name varchar(255) not null,
    supplier_contact_info text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table supply_order_status(
    status_id serial primary key,
    status_name varchar(50) not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);
insert into supply_order_status(status_name, description) values
('Pending', 'Order is pending'),
('Shipped', 'Order has been shipped'),
('Delivered', 'Order has been delivered'),
('Cancelled', 'Order has been cancelled');

create table supply_order(
    supply_order_id uuid primary key default gen_random_uuid(),
    supplier_id uuid not null references supplies_module.supplier(supplier_id) on delete cascade,
    warehouse_id uuid not null references inventory_module.warehouse(warehouse_id) on delete cascade,
    supply_order_date date default current_date,
    expected_delivery_date date,
    supply_order_status_id integer not null references supplies_module.supply_order_status(status_id) default 1,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table supply_order_item(
    supply_order_item_id uuid primary key default gen_random_uuid(),
    supply_order_id uuid not null references supplies_module.supply_order(supply_order_id) on delete cascade,
    product_id uuid not null references core.product(product_id) on delete cascade,
    quantity_ordered integer not null,
    unit_price numeric(10,2) not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table supply_order_status(
    status_id serial primary key,
    status_name varchar(50) not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table supply_order_tracking(
    supply_order_tracking_id uuid primary key default gen_random_uuid(),
    supply_order_id uuid not null references supplies_module.supply_order(supply_order_id) on delete cascade,
    previous_status_id int references supplies_module.supply_order_status(status_id),
    new_status_id int not null references supplies_module.supply_order_status(status_id),
    notes text,
    changed_at timestamp default current_timestamp
);

create table supplier_invoice(
    supplier_invoice_id uuid primary key default gen_random_uuid(),
    supply_order_id uuid not null references supplies_module.supply_order(supply_order_id) on delete cascade,
    invoice_number varchar(100) not null,
    invoice_date timestamp default current_timestamp,
    due_date date,
    subtotal_amount numeric(10,2) not null,
    tax_amount numeric(10,2) not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table supplier_invoice_item(
    supplier_invoice_item_id uuid primary key default gen_random_uuid(),
    supplier_invoice_id uuid not null references supplies_module.supplier_invoice(supplier_invoice_id) on delete cascade,
    product_id uuid not null references core.product(product_id) on delete cascade,
    quantity_billed integer not null,
    unit_price numeric(10,2) not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table goods_receipt(
    goods_receipt_id uuid primary key default gen_random_uuid(),
    supply_order_id uuid not null references supplies_module.supply_order(supply_order_id) on delete cascade,
    received_date timestamp default current_timestamp,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table goods_receipt_item(
    goods_receipt_item_id uuid primary key default gen_random_uuid(),
    goods_receipt_id uuid not null references supplies_module.goods_receipt(goods_receipt_id) on delete cascade,
    product_id uuid not null references core.product(product_id) on delete cascade,
    quantity_received integer not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table account_payable_status(
    status_id serial primary key,
    status_name varchar(50) not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);
insert into account_payable_status(status_name, description) values
('Pending', 'Payment is pending'),
('Paid', 'Payment has been made'),
('Overdue', 'Payment is overdue');

create table account_payable(
    account_payable_id uuid primary key default gen_random_uuid(),
    supply_order_id uuid not null references supplies_module.supply_order(supply_order_id) on delete cascade,
    amount_due numeric(10,2) not null,
    due_date date not null,
    account_status integer not null references supplies_module.account_payable_status(status_id),
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table supply_order_payment(
    payment_id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null references core.tenant(tenant_id) on delete cascade,
    account_payable_id uuid not null references supplies_module.account_payable(account_payable_id)
    supplier_invoice_id uuid not null references supplies_module.supplier_invoice(supplier_invoice_id) on delete cascade,
    payment_date timestamp default current_timestamp,
    amount_paid numeric(10,2) not null,
    payment_method uuid not null references core.payment_method(payment_method_id) on delete cascade,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table supply_order_payment_alert_type(
    payment_alert_type_id serial primary key,
    payment_alert_type_name varchar(50) not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);
insert into payment_alert_type(payment_alert_type_name, description) values
('Upcoming Due Date', 'Alert for upcoming payment due date'),
('Urgent Payment', 'Alert for urgent payments'),
('Overdue Payment', 'Alert for overdue payments');

create table supply_order_payment_alert(
    payment_alert_id uuid primary key default gen_random_uuid(),
    account_payable_id uuid not null references supplies_module.account_payable(account_payable_id) on delete cascade,
    payment_alert_type_id integer not null references supplies_module.payment_alert_type(payment_alert_type_id),
    alert_date timestamp default current_timestamp,
    is_resolved boolean default false,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table supply_order_payment_alert_config(
    payment_alert_config_id uuid primary key default gen_random_uuid(),
    tenant_id uuid unique not null references core.tenant(tenant_id) on delete cascade,
    warning_days_before_due integer default 7,
    urgent_days_before_due integer default 3,
    email_notifications_enabled boolean default true,
    sms_notifications_enabled boolean default false,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create table three_way_matching(
    matching_id uuid primary key default gen_random_uuid(),
    supply_order_id uuid not null references supplies_module.supply_order(supply_order_id) on delete cascade,
    goods_receipt_id uuid not null references supplies_module.goods_receipt(goods_receipt_id) on delete cascade,
    supplier_invoice_id uuid not null references supplies_module.supplier_invoice(supplier_invoice_id) on delete cascade,
    amounts_matched boolean default false,
    quantities_matched boolean default false,
    is_matched boolean default false,
    matched_at timestamp,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);


-- ==========================================================================
--                          FUNCTIONS AND TRIGGERS
-- ==========================================================================


create or replace function create_supply_order(
    _supplier_id uuid,
    _warehouse_id uuid,
    _expected_delivery_date date
) returns uuid language plpgsql
as $$
declare
    _supply_order_id uuid;
begin
    insert into supplies_module.supply_order(
        supplier_id,
        warehouse_id,
        supply_order_date,
        expected_delivery_date,
        supply_order_status_id
    ) values (
        _supplier_id,
        _warehouse_id,
        current_date,
        expected_delivery_date,
        1
    ) returning supply_order_id into _supply_order_id;

    return _supply_order_id;
end;
$$ language plpgsql;


create or replace function update_order_status(
    _new_status_id integer,
    _supply_order_id uuid
)
returns trigger as $$
begin
    update supplies_module.supply_order
    set supply_order_status_id = _new_status_id,
        updated_at = current_timestamp
    where supply_order_id = new.supply_order_id;
    return new;

    insert into supplies_module.supply_order_tracking(
        supply_order_id,
        previous_status_id,
        new_status_id,
        notes,
        changed_at
    ) values (
        new.supply_order_id,
        old.supply_order_status_id,
        _new_status_id,
        'Status updated via trigger',
        current_timestamp
    );
end;
$$ language plpgsql;


drop trigger if exists update_supplier_timestamp on supplies.supplier;
create trigger update_supplier_timestamp before update on supplies.supplier
for each row execute function core.update_timestamp();

drop trigger if exists update_supply_order_timestamp on supplies.supply_order;
create trigger update_supply_order_timestamp before update on supplies.supply_order
for each row execute function core.update_timestamp();

drop trigger if exists update_supply_order_item_timestamp on supplies.supply_order_item;
create trigger update_supply_order_item_timestamp before update on supplies.supply_order_item
for each row execute function core.update_timestamp();

drop trigger if exists update_supplier_invoice_timestamp on supplies.supplier_invoice;
create trigger update_supplier_invoice_timestamp before update on supplies.supplier_invoice
for each row execute function core.update_timestamp();

drop trigger if exists update_supplier_invoice_item_timestamp on supplies.supplier_invoice_item;
create trigger update_supplier_invoice_item_timestamp before update on supplies.supplier_invoice_item
for each row execute function core.update_timestamp();

drop trigger if exists update_goods_receipt_timestamp on supplies.goods_receipt;
create trigger update_goods_receipt_timestamp before update on supplies.goods_receipt
for each row execute function core.update_timestamp();

drop trigger if exists update_goods_receipt_item_timestamp on supplies.goods_receipt_item;
create trigger update_goods_receipt_item_timestamp before update on supplies.goods_receipt_item
for each row execute function core.update_timestamp();

drop trigger if exists update_account_payable_timestamp on supplies.account_payable;
create trigger update_account_payable_timestamp before update on supplies.account_payable
for each row execute function core.update_timestamp();

drop trigger if exists update_supply_order_payment_timestamp on supplies.supply_order_payment;
create trigger update_supply_order_payment_timestamp before update on supplies.supply_order_payment
for each row execute function core.update_timestamp();

drop trigger if exists update_supply_order_payment_alert_timestamp on supplies.supply_order_payment_alert;
create trigger update_supply_order_payment_alert_timestamp before update on supplies.supply_order_payment_alert
for each row execute function core.update_timestamp();

drop trigger if exists update_supply_order_payment_alert_config_timestamp on supplies.supply_order_payment_alert_config;
create trigger update_supply_order_payment_alert_config_timestamp before update on supplies.supply_order_payment_alert_config
for each row execute function core.update_timestamp();

drop trigger if exists update_three_way_matching_timestamp on supplies.three_way_matching;
create trigger update_three_way_matching_timestamp before update on supplies.three_way_matching
for each row execute function core.update_timestamp();


