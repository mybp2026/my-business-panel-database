-- SCHEMA: purchase
create schema if not exists purchase_module;
set search_path to purchase_module;

CREATE TABLE IF NOT EXISTS supplier(
    supplier_id uuid primary key default gen_random_uuid(),
    supplier_name varchar(255) not null,
    supplier_contact_info text,
    supplier_address text,
    supplier_notes text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_supplier_name on purchase_module.supplier(supplier_name);

CREATE TABLE IF NOT EXISTS supplier_branch(
    supplier_branch_id uuid primary key default gen_random_uuid(),
    supplier_id uuid not null REFERENCES purchase_module.supplier(supplier_id) on delete cascade,
    branch_id uuid not null REFERENCES general.branch(branch_id) on delete cascade,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,

    unique(supplier_id, branch_id)
);

CREATE TABLE IF NOT EXISTS purchase_order_status(
    status_id serial primary key,
    status_name varchar(50) not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS purchase_order(
    purchase_order_id uuid primary key default gen_random_uuid(),
    supplier_id uuid not null REFERENCES purchase_module.supplier(supplier_id) on delete cascade,
    warehouse_id uuid not null REFERENCES inventory_module.warehouse(warehouse_id) on delete cascade,
    purchase_order_date date default current_date,
    expected_delivery_date date,
    purchase_order_status_id integer not null REFERENCES purchase_module.purchase_order_status(status_id) default 1,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS purchase_order_item(
    purchase_order_item_id uuid primary key default gen_random_uuid(),
    purchase_order_id uuid not null REFERENCES purchase_module.purchase_order(purchase_order_id) on delete cascade,
    tenant_id uuid not null,                                                         
    product_id uuid not null,
    quantity_ordered integer not null,
    unit_price numeric(12,3) not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,

    FOREIGN KEY (tenant_id, product_id) REFERENCES general.product(tenant_id, product_id) on delete cascade
);

CREATE TABLE IF NOT EXISTS purchase_order_tracking(
    purchase_order_tracking_id uuid primary key default gen_random_uuid(),
    purchase_order_id uuid not null REFERENCES purchase_module.purchase_order(purchase_order_id) on delete cascade,
    previous_status_id int REFERENCES purchase_module.purchase_order_status(status_id),
    new_status_id int not null REFERENCES purchase_module.purchase_order_status(status_id),
    notes text,
    changed_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS supplier_invoice(
    supplier_invoice_id uuid primary key default gen_random_uuid(),
    purchase_order_id uuid not null REFERENCES purchase_module.purchase_order(purchase_order_id) on delete cascade,
    invoice_number varchar(100) not null,
    invoice_date timestamp default current_timestamp,
    payment_condition varchar(10) not null default 'CREDIT', 
    due_date date,
    subtotal_amount numeric(12,3) not null,
    tax_rate numeric(5,2) not null default 13.00,
    tax_amount numeric(12,3) generated always as (round(subtotal_amount * (tax_rate / 100), 3)) stored,
    total_amount numeric(12,3) generated always as (
        subtotal_amount + round(subtotal_amount * (tax_rate / 100), 3)
    ) stored,    
    paid boolean default false,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,
    
    check (payment_condition in ('CREDIT', 'IN_FULL'))
);

CREATE TABLE IF NOT EXISTS supplier_invoice_item(
    supplier_invoice_item_id uuid primary key default gen_random_uuid(),
    supplier_invoice_id uuid not null REFERENCES purchase_module.supplier_invoice(supplier_invoice_id) on delete cascade,
    tenant_id uuid not null,                                                         
    product_id uuid not null,
    quantity_billed integer not null,
    unit_price numeric(12,3) not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,

    FOREIGN KEY (tenant_id, product_id) REFERENCES general.product(tenant_id, product_id) on delete cascade
);

CREATE TABLE IF NOT EXISTS goods_receipt(
    goods_receipt_id uuid primary key default gen_random_uuid(),
    purchase_order_id uuid not null REFERENCES purchase_module.purchase_order(purchase_order_id) on delete cascade,
    received_date timestamp default current_timestamp,
    subtotal_amount numeric(12,3) default 0,
    tax_amount numeric(12,3) default 0,
    total_amount numeric(12,3) generated always as (subtotal_amount + tax_amount) stored,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS goods_receipt_item(
    goods_receipt_item_id uuid primary key default gen_random_uuid(),
    goods_receipt_id uuid not null REFERENCES purchase_module.goods_receipt(goods_receipt_id) on delete cascade,
    tenant_id uuid not null,                                                         
    product_id uuid not null,
    quantity_received integer not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,

    FOREIGN KEY (tenant_id, product_id) REFERENCES general.product(tenant_id, product_id) on delete cascade
);

CREATE TABLE IF NOT EXISTS purchase_module.purchase_account_payable(
    purchase_account_payable_id uuid primary key default gen_random_uuid(),
    account_payable_id uuid NOT NULL UNIQUE REFERENCES general.account_payable(account_payable_id) ON DELETE CASCADE,
    purchase_order_id uuid NOT NULL UNIQUE REFERENCES purchase_module.purchase_order(purchase_order_id) ON DELETE CASCADE,
    tax_amount numeric(12,3) default 0,
    account_payable_status INTEGER REFERENCES general.account_payable_status(status_id),
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS purchase_module.purchase_order_payment_alert(
    payment_alert_id uuid primary key default gen_random_uuid(),
    purchase_account_payable_id uuid not null REFERENCES purchase_module.purchase_account_payable(purchase_account_payable_id) on delete cascade,
    payment_alert_type_id integer not null REFERENCES purchase_module.purchase_order_payment_alert_type(payment_alert_type_id),
    alert_date timestamp default current_timestamp,
    is_resolved boolean default false,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS purchase_order_payment_alert_type(
    payment_alert_type_id serial primary key,
    payment_alert_type_name varchar(50) not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS purchase_order_payment_alert(
    payment_alert_id uuid primary key default gen_random_uuid(),
    purchase_account_payable_id uuid not null REFERENCES purchase_module.purchase_account_payable(purchase_account_payable_id) on delete cascade,
    payment_alert_type_id integer not null REFERENCES purchase_module.purchase_order_payment_alert_type(payment_alert_type_id),
    alert_date timestamp default current_timestamp,
    is_resolved boolean default false,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS purchase_order_payment_alert_config(
    payment_alert_config_id uuid primary key default gen_random_uuid(),
    tenant_id uuid unique not null REFERENCES general.tenant(tenant_id) on delete cascade,
    warning_days_before_due integer default 7,
    urgent_days_before_due integer default 3,
    email_notifications_enabled boolean default true,
    sms_notifications_enabled boolean default false,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS three_way_matching(
    matching_id uuid primary key default gen_random_uuid(),
    purchase_order_id uuid not null REFERENCES purchase_module.purchase_order(purchase_order_id) on delete cascade,
    goods_receipt_id uuid not null REFERENCES purchase_module.goods_receipt(goods_receipt_id) on delete cascade,
    supplier_invoice_id uuid not null REFERENCES purchase_module.supplier_invoice(supplier_invoice_id) on delete cascade,
    amounts_matched boolean default false,
    quantities_matched boolean default false,
    is_matched boolean default false,
    matched_at timestamp,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);
