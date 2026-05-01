-- Migration: ensure currency_id column exists in purchase_order_payment
-- This is a defensive migration that ensures the column exists and is properly typed.
-- It's safe to run multiple times.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'purchase_schema'
    AND table_name = 'purchase_order_payment'
    AND column_name = 'currency_id'
  ) THEN
    ALTER TABLE purchase_schema.purchase_order_payment
      ADD COLUMN currency_id INTEGER
        REFERENCES general_schema.currency(currency_id)
        DEFAULT 1;

    UPDATE purchase_schema.purchase_order_payment
      SET currency_id = 1
      WHERE currency_id IS NULL;

    ALTER TABLE purchase_schema.purchase_order_payment
      ALTER COLUMN currency_id SET NOT NULL;
  END IF;
END $$;
