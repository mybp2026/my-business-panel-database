-- ======================================================
-- MIGRATION: pos_schema/008-invoice-system-overhaul.sql
-- ======================================================
-- Author: David
-- Description: Overhauls the POS invoice system:
--   1. Renames `bill` → `digital_sale_invoice` with new fields
--   2. Renames `bill_payment` → `digital_sale_invoice_payment`
--   3. Creates `electronic_sale_invoice` table (Costa Rica Hacienda format)
--   4. Creates `electronic_sale_invoice_items` table
--   5. Adds `has_electronic_invoice` flag to `sale` table
--   6. Updates all FK references (return_transaction, score_transaction)
--   7. Updates all indexes and triggers
--
-- Dependencies: pos_schema.sql, all previous migrations applied
-- Breaking Changes: YES - Renames core tables (bill → digital_sale_invoice)
--   All queries referencing pos_schema.bill must be updated.
-- Rollback: See bottom of file
-- ======================================================

BEGIN;

SET SEARCH_PATH TO pos_schema;

-- ======================================================
-- STEP 1: Rename bill → digital_sale_invoice
-- ======================================================

ALTER TABLE pos_schema.bill RENAME TO digital_sale_invoice;

-- Add new columns to digital_sale_invoice
ALTER TABLE pos_schema.digital_sale_invoice
    ADD COLUMN IF NOT EXISTS seller_name VARCHAR(150),
    ADD COLUMN IF NOT EXISTS terminal_name VARCHAR(100),
    ADD COLUMN IF NOT EXISTS points_accumulated INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS ad_message TEXT,
    ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(50),
    ADD COLUMN IF NOT EXISTS amount_paid NUMERIC(10,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS change_amount NUMERIC(10,2) DEFAULT 0;

-- Rename billed_at → invoiced_at for clarity
ALTER TABLE pos_schema.digital_sale_invoice 
    RENAME COLUMN billed_at TO invoiced_at;

-- Rename existing index
DROP INDEX IF EXISTS idx_bill_sale_id;
CREATE INDEX IF NOT EXISTS idx_digital_sale_invoice_sale_id 
    ON pos_schema.digital_sale_invoice(sale_id);

-- ======================================================
-- STEP 2: Rename bill_payment → digital_sale_invoice_payment
-- ======================================================

ALTER TABLE pos_schema.bill_payment RENAME TO digital_sale_invoice_payment;

-- Rename the bill_id column to digital_sale_invoice_id
ALTER TABLE pos_schema.digital_sale_invoice_payment 
    RENAME COLUMN bill_id TO digital_sale_invoice_id;

-- ======================================================
-- STEP 3: Update return_transaction FK (bill_id → digital_sale_invoice_id)
-- ======================================================

ALTER TABLE pos_schema.return_transaction 
    RENAME COLUMN bill_id TO digital_sale_invoice_id;

DROP INDEX IF EXISTS idx_return_transaction_bill_id;
CREATE INDEX IF NOT EXISTS idx_return_transaction_digital_sale_invoice_id 
    ON pos_schema.return_transaction(digital_sale_invoice_id);

-- ======================================================
-- STEP 4: Update score_transaction FK (bill_id → digital_sale_invoice_id)
-- ======================================================

ALTER TABLE pos_schema.score_transaction 
    RENAME COLUMN bill_id TO digital_sale_invoice_id;

-- ======================================================
-- STEP 5: Add has_electronic_invoice flag to sale table
-- ======================================================

ALTER TABLE pos_schema.sale
    ADD COLUMN IF NOT EXISTS has_electronic_invoice BOOLEAN DEFAULT FALSE;

-- ======================================================
-- STEP 6: Create electronic_sale_invoice table
-- (Costa Rica Hacienda electronic invoice format)
-- ======================================================

CREATE TABLE IF NOT EXISTS pos_schema.electronic_sale_invoice (
    electronic_sale_invoice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL REFERENCES pos_schema.sale(sale_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE,

    -- Key (50 digits) - Unique identifier for Hacienda
    key_number VARCHAR(50) NOT NULL UNIQUE,

    -- Consecutive number (20 digits) - Sequential number per POS terminal
    consecutive_number VARCHAR(20) NOT NULL,

    -- Issue date
    issue_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Issuer (seller) info
    issuer_name VARCHAR(150) NOT NULL,
    issuer_identification VARCHAR(20) NOT NULL,
    issuer_identification_type VARCHAR(2) NOT NULL,  -- 01=Individual, 02=Legal Entity, 03=DIMEX, 04=NITE
    issuer_email VARCHAR(200),
    issuer_phone VARCHAR(20),

    -- Receiver (buyer) info
    receiver_name VARCHAR(150),
    receiver_identification VARCHAR(20),
    receiver_identification_type VARCHAR(2),
    receiver_email VARCHAR(200),

    -- Sale conditions
    sale_condition VARCHAR(2) NOT NULL DEFAULT '01',  -- 01=Cash, 02=Credit, 03=Consignment
    payment_method VARCHAR(2) NOT NULL DEFAULT '01',  -- 01=Cash, 02=Card, 03=Check, 04=Transfer
    credit_days VARCHAR(10),

    -- Invoice summary
    total_taxed_services NUMERIC(18,5) DEFAULT 0,
    total_exempt_services NUMERIC(18,5) DEFAULT 0,
    total_exonerated_services NUMERIC(18,5) DEFAULT 0,
    total_taxed_goods NUMERIC(18,5) DEFAULT 0,
    total_exempt_goods NUMERIC(18,5) DEFAULT 0,
    total_exonerated_goods NUMERIC(18,5) DEFAULT 0,
    total_taxable NUMERIC(18,5) DEFAULT 0,
    total_exempt NUMERIC(18,5) DEFAULT 0,
    total_exonerated NUMERIC(18,5) DEFAULT 0,
    total_sale NUMERIC(18,5) NOT NULL DEFAULT 0,
    total_discounts NUMERIC(18,5) DEFAULT 0,
    total_net_sale NUMERIC(18,5) NOT NULL DEFAULT 0,
    total_tax NUMERIC(18,5) DEFAULT 0,
    total_voucher NUMERIC(18,5) NOT NULL DEFAULT 0,

    -- XML digital signature
    xml_signed TEXT,

    -- Hacienda response
    hacienda_status VARCHAR(20) DEFAULT 'pending',  -- pending, accepted, rejected
    hacienda_response_xml TEXT,
    hacienda_response_date TIMESTAMP,

    -- Metadata
    currency_id INTEGER REFERENCES general_schema.currency(currency_id) ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_electronic_sale_invoice_sale_id 
    ON pos_schema.electronic_sale_invoice(sale_id);
CREATE INDEX IF NOT EXISTS idx_electronic_sale_invoice_tenant_id 
    ON pos_schema.electronic_sale_invoice(tenant_id);
CREATE INDEX IF NOT EXISTS idx_electronic_sale_invoice_key_number 
    ON pos_schema.electronic_sale_invoice(key_number);
CREATE INDEX IF NOT EXISTS idx_electronic_sale_invoice_issue_date 
    ON pos_schema.electronic_sale_invoice(issue_date);

-- ======================================================
-- STEP 7: Create electronic_sale_invoice_items table
-- (References base product via cabys_code from product_variant)
-- ======================================================

CREATE TABLE IF NOT EXISTS pos_schema.electronic_sale_invoice_items (
    electronic_sale_invoice_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    electronic_sale_invoice_id UUID NOT NULL REFERENCES pos_schema.electronic_sale_invoice(electronic_sale_invoice_id) ON DELETE CASCADE,
    
    -- Line number in the invoice
    line_number INTEGER NOT NULL,

    -- Product info (resolved from product_variant → product via cabys_code)
    cabys_code VARCHAR(13) NOT NULL REFERENCES general_schema.product(cabys_code) ON DELETE RESTRICT,
    description VARCHAR(200) NOT NULL,  -- Product description

    -- Quantity and units
    quantity NUMERIC(16,3) NOT NULL,
    unit_of_measure VARCHAR(20) NOT NULL DEFAULT 'Unid',
    commercial_unit_of_measure VARCHAR(20),

    -- Pricing
    unit_price NUMERIC(18,5) NOT NULL,
    total_amount NUMERIC(18,5) NOT NULL,

    -- Discounts (optional)
    discount_amount NUMERIC(18,5) DEFAULT 0,
    discount_nature VARCHAR(80),

    -- Subtotal
    subtotal NUMERIC(18,5) NOT NULL,

    -- Tax (IVA)
    tax_code VARCHAR(2) DEFAULT '01',     -- 01 = IVA
    tax_rate_code VARCHAR(2) DEFAULT '08', -- 08 = Standard rate 13%
    tax_rate NUMERIC(5,2) DEFAULT 13.00,
    tax_amount NUMERIC(18,5) DEFAULT 0,
    tax_exemption_amount NUMERIC(18,5) DEFAULT 0,

    -- Exemption (optional)
    exemption_document_type VARCHAR(2),
    exemption_document_number VARCHAR(40),
    exemption_institution VARCHAR(160),
    exemption_date TIMESTAMP,
    exemption_percentage NUMERIC(3,0),

    -- Line total
    total_line_amount NUMERIC(18,5) NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_electronic_invoice_items_invoice 
    ON pos_schema.electronic_sale_invoice_items(electronic_sale_invoice_id);
CREATE INDEX IF NOT EXISTS idx_electronic_invoice_items_cabys 
    ON pos_schema.electronic_sale_invoice_items(cabys_code);

-- ======================================================
-- STEP 8: Update timestamp triggers
-- ======================================================

-- Drop old bill triggers
DROP TRIGGER IF EXISTS update_bill_timestamp ON pos_schema.digital_sale_invoice;
DROP TRIGGER IF EXISTS update_bill_payment_timestamp ON pos_schema.digital_sale_invoice_payment;

-- Create new timestamp triggers for renamed tables
CREATE TRIGGER update_digital_sale_invoice_timestamp 
    BEFORE UPDATE ON pos_schema.digital_sale_invoice
    FOR EACH ROW EXECUTE FUNCTION general_schema.update_timestamp();

CREATE TRIGGER update_digital_sale_invoice_payment_timestamp 
    BEFORE UPDATE ON pos_schema.digital_sale_invoice_payment
    FOR EACH ROW EXECUTE FUNCTION general_schema.update_timestamp();

-- Add timestamp triggers for new tables
CREATE TRIGGER update_electronic_sale_invoice_timestamp 
    BEFORE UPDATE ON pos_schema.electronic_sale_invoice
    FOR EACH ROW EXECUTE FUNCTION general_schema.update_timestamp();

CREATE TRIGGER update_electronic_sale_invoice_items_timestamp 
    BEFORE UPDATE ON pos_schema.electronic_sale_invoice_items
    FOR EACH ROW EXECUTE FUNCTION general_schema.update_timestamp();

COMMIT;

-- ======================================================
-- ROLLBACK (run manually if needed):
-- ======================================================
-- BEGIN;
-- 
-- SET SEARCH_PATH TO pos_schema;
-- 
-- DROP TABLE IF EXISTS pos_schema.electronic_sale_invoice_items CASCADE;
-- DROP TABLE IF EXISTS pos_schema.electronic_sale_invoice CASCADE;
-- 
-- -- Remove has_electronic_invoice from sale
-- ALTER TABLE pos_schema.sale DROP COLUMN IF EXISTS has_electronic_invoice;
-- 
-- -- Revert score_transaction column name
-- ALTER TABLE pos_schema.score_transaction 
--     RENAME COLUMN digital_sale_invoice_id TO bill_id;
-- 
-- -- Revert return_transaction column name
-- ALTER TABLE pos_schema.return_transaction 
--     RENAME COLUMN digital_sale_invoice_id TO bill_id;
-- DROP INDEX IF EXISTS idx_return_transaction_digital_sale_invoice_id;
-- CREATE INDEX IF NOT EXISTS idx_return_transaction_bill_id 
--     ON pos_schema.return_transaction(bill_id);
-- 
-- -- Revert digital_sale_invoice_payment → bill_payment
-- ALTER TABLE pos_schema.digital_sale_invoice_payment 
--     RENAME COLUMN digital_sale_invoice_id TO bill_id;
-- ALTER TABLE pos_schema.digital_sale_invoice_payment RENAME TO bill_payment;
-- 
-- -- Revert digital_sale_invoice → bill
-- ALTER TABLE pos_schema.digital_sale_invoice 
--     RENAME COLUMN invoiced_at TO billed_at;
-- ALTER TABLE pos_schema.digital_sale_invoice
--     DROP COLUMN IF EXISTS seller_name,
--     DROP COLUMN IF EXISTS terminal_name,
--     DROP COLUMN IF EXISTS points_accumulated,
--     DROP COLUMN IF EXISTS ad_message,
--     DROP COLUMN IF EXISTS invoice_number,
--     DROP COLUMN IF EXISTS amount_paid,
--     DROP COLUMN IF EXISTS change_amount;
-- DROP INDEX IF EXISTS idx_digital_sale_invoice_sale_id;
-- ALTER TABLE pos_schema.digital_sale_invoice RENAME TO bill;
-- CREATE INDEX IF NOT EXISTS idx_bill_sale_id ON pos_schema.bill(sale_id);
-- 
-- -- Revert timestamp triggers
-- DROP TRIGGER IF EXISTS update_digital_sale_invoice_timestamp ON pos_schema.bill;
-- DROP TRIGGER IF EXISTS update_digital_sale_invoice_payment_timestamp ON pos_schema.bill_payment;
-- DROP TRIGGER IF EXISTS update_electronic_sale_invoice_timestamp ON pos_schema.electronic_sale_invoice;
-- DROP TRIGGER IF EXISTS update_electronic_sale_invoice_items_timestamp ON pos_schema.electronic_sale_invoice_items;
-- CREATE TRIGGER update_bill_timestamp BEFORE UPDATE ON pos_schema.bill
--     FOR EACH ROW EXECUTE FUNCTION general_schema.update_timestamp();
-- CREATE TRIGGER update_bill_payment_timestamp BEFORE UPDATE ON pos_schema.bill_payment
--     FOR EACH ROW EXECUTE FUNCTION general_schema.update_timestamp();
-- 
-- COMMIT;
