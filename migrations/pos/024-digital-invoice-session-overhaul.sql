-- 024-digital-invoice-session-overhaul.sql
-- Audit: 2026-05-04 davidpaz.dev@gmail.com
-- Purpose: Remove deprecated columns from digital_sale_invoice (seller_name, invoice_number,
--          cash_register_id). Replace cash_register_id with cash_register_session_id FK so
--          the session — and therefore the seller — can be derived from the session record.
--          Also set due_date default to CURRENT_DATE so it is always populated.

-- ROLLBACK (commented):
-- DROP INDEX IF EXISTS pos_schema.idx_digital_sale_invoice_cash_register_session;
-- ALTER TABLE pos_schema.digital_sale_invoice DROP COLUMN IF EXISTS cash_register_session_id;
-- ALTER TABLE pos_schema.digital_sale_invoice
--     ADD COLUMN cash_register_id UUID REFERENCES pos_schema.cash_register(cash_register_id) ON DELETE SET NULL,
--     ADD COLUMN seller_name VARCHAR(150),
--     ADD COLUMN invoice_number VARCHAR(50);
-- CREATE INDEX IF NOT EXISTS idx_digital_sale_invoice_cash_register
--     ON pos_schema.digital_sale_invoice(cash_register_id);
-- ALTER TABLE pos_schema.digital_sale_invoice ALTER COLUMN due_date DROP DEFAULT;

-- 1. Drop deprecated columns (PostgreSQL automatically drops dependent indexes/constraints)
ALTER TABLE pos_schema.digital_sale_invoice
    DROP COLUMN IF EXISTS seller_name,
    DROP COLUMN IF EXISTS invoice_number,
    DROP COLUMN IF EXISTS cash_register_id;

-- 2. Replace with cash_register_session_id FK
ALTER TABLE pos_schema.digital_sale_invoice
    ADD COLUMN IF NOT EXISTS cash_register_session_id UUID
        REFERENCES pos_schema.cash_register_session(cash_register_session_id)
        ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_digital_sale_invoice_cash_register_session
    ON pos_schema.digital_sale_invoice(cash_register_session_id);

-- 3. due_date now defaults to the creation date
ALTER TABLE pos_schema.digital_sale_invoice
    ALTER COLUMN due_date SET DEFAULT CURRENT_DATE;
