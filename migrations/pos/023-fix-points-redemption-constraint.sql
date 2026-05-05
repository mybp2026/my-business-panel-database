-- Fix check_points_redemption constraint: loyalty points is payment_method_id = 5,
-- not 4 (which is bank transfer). The wrong ID prevented points-redemption payments
-- from being inserted, causing the sale transaction to rollback and the customer
-- score to never be decremented.

ALTER TABLE pos_schema.customer_payment
    DROP CONSTRAINT IF EXISTS check_points_redemption;

ALTER TABLE pos_schema.customer_payment
    ADD CONSTRAINT check_points_redemption CHECK (
        (is_points_redemption = true AND points_redeemed IS NOT NULL AND points_redeemed > 0 AND payment_method_id = 5) OR
        (is_points_redemption = false)
    );
