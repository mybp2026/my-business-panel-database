-- MPP2 + MPP3: Replace single customer_segment_id with is_universal flag + junction table
-- is_universal = true  → promotion applies to all segments AND walk-in (no-customer) sales
-- is_universal = false → promotion applies only to the segments listed in promotion_customer_segment

-- Step 1: add is_universal flag (default TRUE so existing promos without a segment become universal)
ALTER TABLE pos_schema.promotion
    ADD COLUMN IF NOT EXISTS is_universal BOOLEAN NOT NULL DEFAULT TRUE;

-- Step 2: create junction table for explicit segment targeting
CREATE TABLE IF NOT EXISTS pos_schema.promotion_customer_segment (
    promotion_id        uuid    NOT NULL REFERENCES pos_schema.promotion(promotion_id) ON DELETE CASCADE,
    customer_segment_id INTEGER NOT NULL REFERENCES general_schema.customer_segment(customer_segment_id) ON DELETE CASCADE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (promotion_id, customer_segment_id)
);

CREATE INDEX IF NOT EXISTS idx_promo_seg_promo
    ON pos_schema.promotion_customer_segment(promotion_id);
CREATE INDEX IF NOT EXISTS idx_promo_seg_segment
    ON pos_schema.promotion_customer_segment(customer_segment_id);

-- Step 3: migrate existing segment assignments into junction table
INSERT INTO pos_schema.promotion_customer_segment (promotion_id, customer_segment_id)
SELECT promotion_id, customer_segment_id
FROM pos_schema.promotion
WHERE customer_segment_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Step 4: mark promos that had an explicit segment as non-universal
UPDATE pos_schema.promotion
SET is_universal = FALSE
WHERE customer_segment_id IS NOT NULL;

-- Step 5: drop the now-redundant column
ALTER TABLE pos_schema.promotion
    DROP COLUMN IF EXISTS customer_segment_id;
