CREATE SCHEMA IF NOT EXISTS pos_schema;
SET SEARCH_PATH TO pos_schema;

CREATE TABLE IF NOT EXISTS sale(
    sale_id uuid primary key default gen_random_uuid(),
    branch_id uuid not null REFERENCES general_schema.branch(branch_id) on delete cascade,  
    sale_date timestamp not null default current_timestamp,
    currency_id integer REFERENCES general_schema.currency(currency_id) on delete set null,
    subtotal_amount numeric(10,2) not null default 0 check (subtotal_amount >= 0),
    tax_amount numeric(10,2) not null default 0 check (tax_amount >= 0),
    total_amount numeric(10,2) not null,
    is_completed boolean default false,
    created_at timestamp not null default current_timestamp,
    updated_at timestamp default current_timestamp
);
CREATE INDEX IF NOT EXISTS idx_sale_branch_id on pos_schema.sale(branch_id);
CREATE INDEX IF NOT EXISTS idx_sale_sale_date on pos_schema.sale(sale_date);

CREATE TABLE IF NOT EXISTS sale_item(
    sale_item_id uuid primary key default gen_random_uuid(),
    sale_id uuid not null REFERENCES pos_schema.sale(sale_id) on delete cascade,
    tenant_id uuid not null, 
    product_id uuid not null,  
    quantity integer not null check (quantity > 0),
    unit_price numeric(10,2) not null check (unit_price >= 0),
    total_price numeric(10,2) not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,
    
    FOREIGN KEY (tenant_id, product_id) 
        REFERENCES general_schema.product(tenant_id, product_id) 
        on delete restrict
);
CREATE INDEX IF NOT EXISTS idx_sale_item_product_id on pos_schema.sale_item(product_id);
CREATE INDEX IF NOT EXISTS idx_sale_item_sale_id on pos_schema.sale_item(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_item_tenant_product on pos_schema.sale_item(tenant_id, product_id);

CREATE TABLE IF NOT EXISTS cash_register(
    cash_register_id uuid primary key default gen_random_uuid(),
    branch_id uuid not null REFERENCES general_schema.branch(branch_id) on delete cascade,
    is_active boolean default true,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS cash_register_session(
    cash_register_session_id uuid primary key default gen_random_uuid(),
    cash_register_id uuid not null REFERENCES pos_schema.cash_register(cash_register_id) on delete cascade,
    user_id uuid not null REFERENCES general_schema.users(user_id) on delete set null,
    opened_at timestamp not null default current_timestamp,
    closed_at timestamp,
    opening_amount numeric(10,2) not null check (opening_amount >= 0),
    closing_amount numeric(10,2) check (closing_amount >= 0),
    is_active boolean default true,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS cash_register_sale(
    cash_register_sale_id uuid primary key default gen_random_uuid(),
    cash_register_session_id uuid not null REFERENCES pos_schema.cash_register_session(cash_register_session_id) on delete cascade,
    sale_id uuid not null unique REFERENCES pos_schema.sale(sale_id) on delete cascade, 
    transaction_time timestamp not null default current_timestamp,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS customer_payment(
    customer_payment_id uuid primary key not null default gen_random_uuid(),
    tenant_customer_id uuid not null REFERENCES general_schema.tenant_customer(tenant_customer_id) on delete cascade,   
    sale_id uuid not null REFERENCES pos_schema.sale(sale_id) on delete cascade,
    payment_method_id integer REFERENCES general_schema.payment_method(payment_method_id) on delete set null,
    is_points_redemption boolean default false,
    points_redeemed integer default 0 check (points_redeemed >= 0),
    points_to_currency_rate numeric(10,4) default 0 check (points_to_currency_rate >= 0),
    payment_amount numeric(10,2) not null check (payment_amount > 0),
    payment_date timestamp not null default current_timestamp,
    currency_id integer REFERENCES general_schema.currency(currency_id) on delete set null,
    verified boolean default false,
    created_at timestamp not null default current_timestamp,
    updated_at timestamp default current_timestamp,

    constraint check_points_redemption
    check (
        (is_points_redemption = true and points_redeemed is not null and points_redeemed > 0 and payment_method_id = 4) or
        (is_points_redemption = false)
    )
);

CREATE TABLE IF NOT EXISTS bill(
    bill_id uuid primary key default gen_random_uuid(),
    tenant_customer_id uuid REFERENCES general_schema.tenant_customer(tenant_customer_id) on delete set null,
    sale_id uuid not null REFERENCES pos_schema.sale(sale_id) on delete cascade,
    currency_id integer REFERENCES general_schema.currency(currency_id) on delete set null,
    subtotal_amount numeric(10,2) not null check (subtotal_amount >= 0),
    tax_amount numeric(10,2) not null check (tax_amount >= 0),
    total_amount numeric(10,2) not null,    
    billed_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);
alter table pos_schema.bill
    add column if not exists due_date date;
CREATE INDEX IF NOT EXISTS idx_bill_sale_id on pos_schema.bill(sale_id);

CREATE TABLE IF NOT EXISTS bill_payment(
    bill_payment_id uuid primary key default gen_random_uuid(),
    bill_id uuid not null REFERENCES pos_schema.bill(bill_id) on delete cascade,
    customer_payment_id uuid not null REFERENCES pos_schema.customer_payment(customer_payment_id) on delete cascade,
    payment_amount numeric(10,2) not null check (payment_amount > 0),
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,

    unique (bill_id, customer_payment_id)
);

CREATE TABLE IF NOT EXISTS return_reason(
    return_reason_id serial primary key,
    reason_code varchar(50) unique not null,
    reason_name varchar(100) not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS return_status(
    return_status_id serial primary key,
    status_name varchar(50) unique not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS return_transaction(
    return_transaction_id uuid primary key default gen_random_uuid(),
    bill_id uuid not null REFERENCES pos_schema.bill(bill_id) on delete cascade,
    tenant_customer_id uuid REFERENCES general_schema.tenant_customer(tenant_customer_id) on delete set null,
    total_refund_amount numeric(10,2) not null check (total_refund_amount >= 0),
    refund_method int REFERENCES general_schema.payment_method(payment_method_id) on delete set null,
    return_status_id integer REFERENCES pos_schema.return_status(return_status_id) on delete set null,
    return_date timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);
CREATE INDEX IF NOT EXISTS idx_return_transaction_bill_id on pos_schema.return_transaction(bill_id);
CREATE INDEX IF NOT EXISTS idx_return_transaction_date on pos_schema.return_transaction(return_date);

CREATE TABLE IF NOT EXISTS return_product(
    return_product_id uuid primary key default gen_random_uuid(),
    return_transaction_id uuid not null REFERENCES pos_schema.return_transaction(return_transaction_id) on delete cascade,
    sale_item_id uuid not null REFERENCES pos_schema.sale_item(sale_item_id) on delete cascade,
    quantity integer not null check (quantity > 0),
    unit_price numeric(10,2) not null check (unit_price >= 0),
    total_price numeric(10,2) not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);
CREATE INDEX IF NOT EXISTS idx_return_product_transaction_id on pos_schema.return_product(return_transaction_id);

CREATE TABLE IF NOT EXISTS promotion_type(
    promotion_type_id serial primary key,
    type_name varchar(50) unique not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS promotion(
    promotion_id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    promotion_name varchar(100) not null,
    promotion_code varchar(50) not null,
    promotion_description text,
    promotion_type_id int REFERENCES pos_schema.promotion_type(promotion_type_id) on delete set null,
    customer_segment_id int REFERENCES general_schema.customer_segment(customer_segment_id) on delete set null,
    promotion_start_date date not null,
    promotion_end_date date not null,
    is_active boolean default false,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,

    check (promotion_end_date > promotion_start_date)
);

CREATE TABLE IF NOT EXISTS promotion_rule(
    promotion_rule_id uuid primary key default gen_random_uuid(),
    promotion_id uuid not null REFERENCES pos_schema.promotion(promotion_id) on delete cascade,
    -- =====================================
    -- Fixed amount or percentage discount
    -- =====================================
    discount_percentage numeric(5,2) check (
        discount_percentage is null or 
        (discount_percentage >= 0 and discount_percentage <= 100)
    ),
    discount_amount numeric(10,2) check (
        discount_amount is null or 
        discount_amount >= 0
    ),
    -- =====================================
    -- Buy X get Y (2x1, 3x2, etc.)
    -- =====================================
    buy_quantity integer,
    get_quantity integer,
    get_discount_percentage numeric(5,2) default 100.00 check (
        get_discount_percentage is null or 
        (get_discount_percentage >= 0 and get_discount_percentage <= 100)
    ),  -- 100% = gratis, 50% = half price
    -- =====================================
    -- Volume discount
    -- =====================================
    min_quantity integer,
    max_quantity integer,
    -- =====================================
    -- Tiered pricing
    -- =====================================
    tier_level integer,
    tier_min_quantity integer,
    tier_max_quantity integer,
    tier_price numeric(10,2),
    tier_discount_percentage numeric(5,2),
    -- =====================================
    -- Minimum purchase amount for promotion
    -- =====================================
    min_purchase_amount numeric(10,2),
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

create type discount_result as (
    discount_amount numeric(10,2),
    discount_percentage numeric(5,2),
    rule_description text,
    success boolean
);

CREATE TABLE IF NOT EXISTS loyalty_program(
    loyalty_program_id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    points_earned_per_currency_unit numeric(5,2) not null default 1.00 check (points_earned_per_currency_unit >= 0),
    points_redeemed_per_currency_unit numeric(10,2) not null default 100.00 check (points_redeemed_per_currency_unit > 0),
    minimum_purchase_for_points numeric(10,2) default 0 check (minimum_purchase_for_points >= 0),
    is_active boolean default true,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS tenant_customer_score(
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    tenant_customer_id uuid not null REFERENCES general_schema.tenant_customer(tenant_customer_id) on delete cascade,
    score integer not null default 0 check (score >= 0),
    lifetime_score integer not null default 0 check (lifetime_score >= 0),
    score_redeemed integer not null default 0 check (score_redeemed >= 0),
    last_earned_at timestamp,
    last_redeemed_at timestamp,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,

    primary key (tenant_customer_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS score_redemption_status(
    score_redemption_status_id serial primary key,
    status_name varchar(50) unique not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS score_transaction_type(
    score_transaction_type_id serial primary key,
    type_name varchar(50) unique not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS score_transaction(
    score_transaction_id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    tenant_customer_id uuid not null REFERENCES general_schema.tenant_customer(tenant_customer_id) on delete cascade,
    transaction_type_id int REFERENCES pos_schema.score_transaction_type(score_transaction_type_id) on delete set null,
    points integer not null,
    bill_id uuid REFERENCES pos_schema.bill(bill_id) on delete set null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS debtor (
    debtor_id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    debt numeric(10, 2) not null default 0.00, -- ? Add check (debt >= 0) 
    missed_payments integer not null default 0
);