-- Allow sales to be registered without a customer (walk-in / anonymous).
-- The base sale table previously declared tenant_customer_id as NOT NULL,
-- which forced the POS to attach a placeholder customer for every sale.

ALTER TABLE pos_schema.sale
  ALTER COLUMN tenant_customer_id DROP NOT NULL;
