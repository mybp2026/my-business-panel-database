-- ============================================================
-- Migration pos-018: customer_payment.tenant_customer_id nullable
-- ------------------------------------------------------------
--   Migration 017 already made pos_schema.sale.tenant_customer_id
--   nullable (walk-in / anonymous sales). The companion table
--   customer_payment was still NOT NULL on the same column,
--   forcing the POS to attach a placeholder customer for every
--   payment row of a walk-in sale. Drop that constraint so
--   anonymous payments can be persisted directly.
-- ============================================================

ALTER TABLE pos_schema.customer_payment
    ALTER COLUMN tenant_customer_id DROP NOT NULL;
