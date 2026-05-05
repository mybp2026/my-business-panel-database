-- MGP3: Add giftable flag and giftable_from threshold to product_variant
-- giftable: whether the product can be given as a gift/reward
-- giftable_from: minimum purchase amount from which this product becomes giftable (NULL = no threshold)

ALTER TABLE general_schema.product_variant
    ADD COLUMN IF NOT EXISTS giftable BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS giftable_from NUMERIC(10,2)
        CHECK (giftable_from IS NULL OR giftable_from >= 0);
