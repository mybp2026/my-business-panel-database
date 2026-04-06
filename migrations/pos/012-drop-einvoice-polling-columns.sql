-- Migration 012: Remove legacy polling columns from electronic_sale_invoice
-- These columns are no longer needed after migrating to BullMQ job queue.
-- The retry state now lives in Redis, not in PostgreSQL.
-- Idempotent: safe to run multiple times.

SET SEARCH_PATH TO pos_schema;

ALTER TABLE pos_schema.electronic_sale_invoice
    DROP COLUMN IF EXISTS check_attempts,
    DROP COLUMN IF EXISTS next_check_at;
