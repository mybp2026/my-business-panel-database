CREATE SCHEMA IF NOT EXISTS general_schema;
SET SEARCH_PATH TO general_schema;

CREATE TABLE IF NOT EXISTS region(
    region_id serial primary key,
    region_name varchar(100) unique not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS tenant(
    tenant_id uuid primary key default gen_random_uuid(),
    tenant_name varchar(100) unique not null,
    region_id integer REFERENCES general_schema.region(region_id) on delete set null,
    contact_email varchar(100) not null,
    is_subscribed boolean default false,
    stripe_id varchar(255) unique default null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS branch(
    branch_id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    branch_name varchar(100) not null,
    branch_address text,
    contact_email varchar(100),
    is_main_branch boolean default false,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);
CREATE UNIQUE INDEX IF NOT EXISTS unique_main_branch_per_tenant 
    on general_schema.branch (tenant_id) 
    where is_main_branch = true;

CREATE TABLE IF NOT EXISTS document_type(
    document_type_id serial primary key, 
    type_name varchar(50) unique not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS customer_segment(
    customer_segment_id serial primary key,
    segment_name varchar(100) unique not null,
    segment_hierarchy integer not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
    );

CREATE TABLE IF NOT EXISTS customer_segment_margin_type(
    customer_segment_margin_type_id serial primary key,
    type_name varchar(50) unique not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS customer_segment_margin(
    customer_segment_margin_id uuid primary key not null default gen_random_uuid(),
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    customer_segment_id int not null REFERENCES general_schema.customer_segment(customer_segment_id) on delete cascade,
    customer_segment_margin_type_id int REFERENCES general_schema.customer_segment_margin_type(customer_segment_margin_type_id) on delete set null,
    spending_threshold numeric(10,2) check (spending_threshold >= 0),
    seniority_months int check (seniority_months >= 0),
    frequency_per_month int check (frequency_per_month >= 0)
);

CREATE TABLE IF NOT EXISTS tenant_customer(
    tenant_customer_id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,  
    first_name varchar(100) not null,
    last_name varchar(100) not null,
    document_type_id integer REFERENCES general_schema.document_type(document_type_id) on delete set null,  
    document_number varchar(50) not null,
    email varchar(255) not null,
    phone varchar(50) not null,
    birthdate date,
    address text,
    is_tenant boolean default false,
    customer_segment_id int default 4 REFERENCES general_schema.customer_segment(customer_segment_id) on delete set null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,
    
    unique(tenant_id, document_number),   
    unique(tenant_id, email),             
    unique(tenant_id, phone)    
);

CREATE TABLE IF NOT EXISTS role(
    role_id serial primary key,
    role_name varchar(50) unique not null,
    role_hierarchy integer not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS users( 
    user_id uuid primary key default gen_random_uuid(),
    tenant_id uuid REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    email varchar(100) unique not null,
    password_hash varchar(255) not null,
    role_id integer REFERENCES general_schema.role(role_id) on delete set null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS currency(
    currency_id serial primary key,
    currency_code char(3) unique not null,
    currency_name varchar(50) not null,
    symbol varchar(10) not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS tax_rate(
    tax_rate_id serial primary key,
    region varchar(100) unique not null,
    region_id integer REFERENCES general_schema.region(region_id) on delete set null,
    rate_percentage numeric(5,2) not null check (rate_percentage >= 0 and rate_percentage <= 100),
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS subscription_type ( 
    subscription_type_id serial primary key,
    subscription_type_name varchar(25) not null,
    subscription_type_detail text not null,
    duration_months int not null,
    subscription_type_cost numeric(5,2)
    -- TODO: corroborar como se gestionarán las suscripciones del SaaS
);

CREATE TABLE IF NOT EXISTS payment_method(
    payment_method_id serial primary key,
    name varchar(50) unique not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS tenant_payment(
    tenant_payment_id uuid primary key default gen_random_uuid(),
    tenant_id uuid REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    payment_method_id integer REFERENCES general_schema.payment_method(payment_method_id) on delete set null,
    payment_amount numeric(10,2) not null check (payment_amount >= 0),
    payment_date timestamp default current_timestamp,
    details varchar(255),
    verified boolean default false,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS subscription(
    subscription_id uuid primary key default gen_random_uuid(),
    tenant_id uuid REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    subscription_type_id integer REFERENCES general_schema.subscription_type(subscription_type_id) on delete set null,
    tenant_payment_id uuid REFERENCES general_schema.tenant_payment(tenant_payment_id) on delete set null,
    start_date date not null,
    end_date date not null,
    is_active boolean default true,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,
    
    check (end_date > start_date)
);

CREATE TABLE IF NOT EXISTS product_category(
    product_category_id serial primary key,
    category_name varchar(100) unique not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS product(
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    product_id uuid not null default gen_random_uuid(),
    sku varchar(50) not null,
    product_name varchar(100) not null,
    product_name_tsv tsvector generated always as (to_tsvector('spanish', product_name)) stored,
    product_description text,
    product_category_id int REFERENCES general_schema.product_category(product_category_id) on delete set null,
    unit_price numeric(10,2) not null check (unit_price >= 0),
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,

    primary key (tenant_id, product_id)   
) partition by hash (tenant_id);
do $$
declare
    i int;
BEGIN
    for i in 0..7 loop
        execute format(
            'CREATE TABLE IF NOT EXISTS general_schema.product_p%s partition of general_schema.product for VALUES with (modulus 8, remainder %s);'
            , i, i);
    end loop;
end;
$$ language plpgsql;
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_tenant_sku on general_schema.product(tenant_id, sku);
CREATE INDEX IF NOT EXISTS idx_product_tenant_btree on general_schema.product(tenant_id);
CREATE INDEX IF NOT EXISTS idx_product_name_fts on general_schema.product using gin ( product_name_tsv );

CREATE TABLE IF NOT EXISTS global_attribute (
    global_attribute_id serial primary key,
    attribute_name varchar(100) not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE UNIQUE INDEX IF NOT EXISTS unique_attribute_name 
    on general_schema.global_attribute (lower(attribute_name));

CREATE TABLE IF NOT EXISTS tenant_attribute (
    tenant_attribute_id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    global_attribute_id int REFERENCES general_schema.global_attribute(global_attribute_id) on delete set null,
    attribute_name varchar(100) not null,
    is_custom boolean default false,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,

    check (
        (global_attribute_id is not null and is_custom = false) or
        (global_attribute_id is null and is_custom = true)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS unique_tenant_attribute_name 
    on general_schema.tenant_attribute (tenant_id, lower(attribute_name));

CREATE TABLE IF NOT EXISTS product_attribute (
    tenant_id uuid not null REFERENCES general_schema.tenant(tenant_id) on delete cascade,
    product_id uuid not null,
    tenant_attribute_id uuid not null REFERENCES general_schema.tenant_attribute(tenant_attribute_id) on delete cascade,
    value text not null,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp,

    primary key (tenant_id, product_id, tenant_attribute_id),

    FOREIGN KEY (tenant_id, product_id) 
        REFERENCES general_schema.product(tenant_id, product_id) 
        on delete cascade
);

CREATE TABLE IF NOT EXISTS account_payable_status(
    status_id serial primary key,
    status_name varchar(50) not null,
    description text,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp
);

CREATE TABLE IF NOT EXISTS account_payable_type (
    account_payable_type_id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS general_schema.account_payable (
    account_payable_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_payable_type_id INT REFERENCES general_schema.account_payable_type(account_payable_type_id) ON DELETE SET NULL,
    account_status integer not null default 1 REFERENCES general_schema.account_payable_status(status_id),
    has_invoice BOOLEAN DEFAULT FALSE,
    has_tax BOOLEAN DEFAULT FALSE,
    subtotal NUMERIC(12,3) NOT NULL CHECK (subtotal >= 0),
    amount_paid NUMERIC(12,3) DEFAULT 0 CHECK (amount_paid >= 0),
    balance_remaining NUMERIC(12,3) GENERATED ALWAYS AS (subtotal - amount_paid) STORED,
    is_paid BOOLEAN DEFAULT FALSE,
    due_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);