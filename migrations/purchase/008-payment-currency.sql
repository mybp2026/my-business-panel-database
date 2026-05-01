-- Migration: add currency_id to purchase_order_payment
-- Allows registering abonos in a currency other than CRC.
-- Defaults to 1 (CRC) so existing rows remain valid.

ALTER TABLE purchase_schema.purchase_order_payment
  ADD COLUMN IF NOT EXISTS currency_id INTEGER
    REFERENCES general_schema.currency(currency_id)
    DEFAULT 1;

UPDATE purchase_schema.purchase_order_payment
  SET currency_id = 1
  WHERE currency_id IS NULL;

ALTER TABLE purchase_schema.purchase_order_payment
  ALTER COLUMN currency_id SET NOT NULL;
