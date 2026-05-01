-- 019-promotion-default-stackable.sql
-- Add is_default and is_stackable flags to pos_schema.promotion.
--   is_default   : while active, this promotion is auto-applied to every new sale.
--   is_stackable : when false, blocks any other promotion from being added on top
--                  while this one is applied.
-- Idempotent.

SET SEARCH_PATH TO pos_schema;

ALTER TABLE pos_schema.promotion
    ADD COLUMN IF NOT EXISTS is_default   BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_stackable BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_promotion_active_default
    ON pos_schema.promotion(tenant_id, is_active, is_default)
    WHERE is_active = TRUE AND is_default = TRUE;
