-- ============================================================
-- Migration 014: Sale Traceability (Financial Module Phase 2)
-- ============================================================
-- Adds:
--   1. seller_user_id to pos_schema.sale
--   2. cost_price_at_sale, sale_price_type, promotion_id,
--      original_price, discount_applied to pos_schema.sale_item
-- ============================================================

BEGIN;

-- -----------------------------------------------------------------
-- 1. Add seller_user_id to sale
-- -----------------------------------------------------------------
ALTER TABLE pos_schema.sale
    ADD COLUMN IF NOT EXISTS seller_user_id UUID
        REFERENCES general_schema.users(user_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_sale_seller
    ON pos_schema.sale(seller_user_id)
    WHERE seller_user_id IS NOT NULL;

COMMENT ON COLUMN pos_schema.sale.seller_user_id IS
    'User who made the sale. Enables sales-by-seller reporting.';

-- -----------------------------------------------------------------
-- 2. Add traceability columns to sale_item
-- -----------------------------------------------------------------
ALTER TABLE pos_schema.sale_item
    ADD COLUMN IF NOT EXISTS cost_price_at_sale NUMERIC(12,3);

ALTER TABLE pos_schema.sale_item
    ADD COLUMN IF NOT EXISTS sale_price_type VARCHAR(20) DEFAULT 'NORMAL'
        CHECK (sale_price_type IN ('NORMAL', 'PROMO', 'SEGMENT', 'MANUAL'));

ALTER TABLE pos_schema.sale_item
    ADD COLUMN IF NOT EXISTS promotion_id UUID
        REFERENCES pos_schema.promotion(promotion_id) ON DELETE SET NULL;

ALTER TABLE pos_schema.sale_item
    ADD COLUMN IF NOT EXISTS original_price NUMERIC(10,2);

ALTER TABLE pos_schema.sale_item
    ADD COLUMN IF NOT EXISTS discount_applied NUMERIC(10,2) DEFAULT 0;

COMMENT ON COLUMN pos_schema.sale_item.cost_price_at_sale IS
    'Snapshot of product weighted_avg_cost at the time of sale. Used for historical profitability.';
COMMENT ON COLUMN pos_schema.sale_item.sale_price_type IS
    'How the sale price was determined: NORMAL (base price), PROMO (promotion), SEGMENT (wholesale/segment margin), MANUAL (override).';
COMMENT ON COLUMN pos_schema.sale_item.promotion_id IS
    'If sale_price_type=PROMO, FK to the promotion that generated the discount.';
COMMENT ON COLUMN pos_schema.sale_item.original_price IS
    'Base price before any discount was applied.';
COMMENT ON COLUMN pos_schema.sale_item.discount_applied IS
    'Amount of discount applied per unit (original_price - unit_price).';

CREATE INDEX IF NOT EXISTS idx_sale_item_price_type
    ON pos_schema.sale_item(sale_price_type);

CREATE INDEX IF NOT EXISTS idx_sale_item_promotion
    ON pos_schema.sale_item(promotion_id)
    WHERE promotion_id IS NOT NULL;

COMMIT;
