-- 020-cash-register-key.sql
-- Add an optional cash register key. Employees must supply it to open/close
-- a cash register session via the CreateSale view; admins bypass the check.
-- Stored in plain text (per product decision); rotate or upgrade to a hashed
-- credential later if the threat model changes.
-- Idempotent.

SET SEARCH_PATH TO pos_schema;

ALTER TABLE pos_schema.cash_register
    ADD COLUMN IF NOT EXISTS cash_register_key VARCHAR(64);

COMMENT ON COLUMN pos_schema.cash_register.cash_register_key IS
    'Optional plain-text key required for non-admin users to open/close a session. NULL = no key required.';
