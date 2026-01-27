-- ======================================================
-- SCHEMA BOOTSTRAP FILE
-- ======================================================

\c mybusinesspaneldb;

BEGIN;

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

-- -----------------
-- EXTENSIONS
-- -----------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------
-- TABLES
-- -----------------
\i schemas/general/general_schema.sql
\i schemas/pos/pos_schema.sql
\i schemas/purchase/purchase_schema.sql
\i schemas/inventory/inventory_schema.sql
\i schemas/hr/hr_schema.sql

-- -----------------
-- FUNCTIONS
-- -----------------
-- \i functions/update_timestamp.sql

-- -----------------
-- SEEDS - CATALOG GENERAL
-- -----------------
\i seeds/catalog/general/001-insert-regions.sql
\i seeds/catalog/general/002-insert-document_types.sql
\i seeds/catalog/general/003-insert-customer-segments.sql
\i seeds/catalog/general/004-insert-customer_segment_margin_types.sql
\i seeds/catalog/general/005-insert-roles.sql
\i seeds/catalog/general/006-insert-currencies.sql
\i seeds/catalog/general/007-insert-tax-rates.sql
\i seeds/catalog/general/008-insert-subscription-types.sql
\i seeds/catalog/general/009-insert-payment_methods.sql
\i seeds/catalog/general/010-insert-account-payable-status.sql
\i seeds/catalog/general/011-insert-account-payable-types.sql

-- -----------------
-- SEEDS - CATALOG POS
-- -----------------
\i seeds/catalog/pos/001-insert-return-reason.sql
\i seeds/catalog/pos/002-insert-return-status.sql
\i seeds/catalog/pos/003-insert-promotion-types.sql
\i seeds/catalog/pos/004-insert-score-redemption-status.sql
\i seeds/catalog/pos/005-insert-score-transaction-types.sql

-- -----------------
-- SEEDS - CATALOG PURCHASE
-- -----------------
\i seeds/catalog/purchase/001-insert-purchase-order-status.sql
\i seeds/catalog/purchase/002-insert-purchase-order-payment-alert-type.sql

-- -----------------
-- SEEDS - CATALOG INVENTORY
-- -----------------
\i seeds/catalog/inventory/001-insert-inventory_log_types.sql

-- -----------------
-- SEEDS - CATALOG HR
-- -----------------
\i seeds/catalog/hr/001-insert-payment-schedules.sql
\i seeds/catalog/hr/002-insert-paysheet-status.sql



-- -----------------
-- INTEGRITY CHECKS
-- -----------------
DO $$
DECLARE
    v_table_name TEXT;
    v_count INT;
    v_failed_tables TEXT[] := '{}';
BEGIN
    FOR v_table_name IN 
        SELECT unnest(ARRAY[
            'general.region',
            'general.role',
            'general.document_type',
            'general.currency',
            'general.payment_method',
            'general.subscription_type',
            'general.customer_segment',
            'general.customer_segment_margin_type',
            'general.tax_rate',
            'general.account_payable_status',
            'general.account_payable_type',
            'pos.return_reason',
            'pos.return_status',
            'pos.promotion_type',
            'pos.score_redemption_status',
            'pos.score_transaction_type',
            'purchase.purchase_order_status',
            'purchase.purchase_order_payment_alert_type',
            'inventory.inventory_log_type',
            'hr_module.payment_schedule',
            'hr_module.paysheet_status'
        ])
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM %s', v_table_name) INTO v_count;
        
        IF v_count = 0 THEN
            v_failed_tables := array_append(v_failed_tables, v_table_name);
        END IF;
    END LOOP;
    
    IF array_length(v_failed_tables, 1) > 0 THEN
        RAISE EXCEPTION 'The following tables are empty after seeding: %', 
            array_to_string(v_failed_tables, ', ');
    END IF;
END $$;

COMMIT;