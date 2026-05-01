-- 031-exchange-rate-updated-at.sql
-- Add updated_at column to general_schema.exchange_rate so admins can edit existing
-- rate records without needing to drop and re-insert. Idempotent.

SET SEARCH_PATH TO general_schema;

ALTER TABLE general_schema.exchange_rate
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

UPDATE general_schema.exchange_rate
   SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP)
 WHERE updated_at IS NULL;
