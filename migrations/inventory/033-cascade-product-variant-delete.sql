-- ============================================================================
-- MIGRATION: inventory/033-cascade-product-variant-delete.sql
-- Date: 2026-05-19
-- Description: Reaffirm ON DELETE CASCADE on all inventory tables that reference
--              general_schema.product_variant. Idempotent: drops and re-adds.
-- ============================================================================
BEGIN;

-- ─── inventory ──────────────────────────────────────────────────────────────

ALTER TABLE inventory_schema.inventory
DROP CONSTRAINT IF EXISTS inventory_product_variant_fkey;


ALTER TABLE inventory_schema.inventory ADD CONSTRAINT inventory_product_variant_fkey
FOREIGN KEY (tenant_id,
             product_variant_id) REFERENCES general_schema.product_variant(tenant_id, product_variant_id) ON
DELETE CASCADE;

-- ─── inventory_log ──────────────────────────────────────────────────────────

ALTER TABLE inventory_schema.inventory_log
DROP CONSTRAINT IF EXISTS inventory_log_product_variant_fkey;


ALTER TABLE inventory_schema.inventory_log ADD CONSTRAINT inventory_log_product_variant_fkey
FOREIGN KEY (tenant_id,
             product_variant_id) REFERENCES general_schema.product_variant(tenant_id, product_variant_id) ON
DELETE CASCADE;

-- ─── inventory_transfer_product ─────────────────────────────────────────────

ALTER TABLE inventory_schema.inventory_transfer_product
DROP CONSTRAINT IF EXISTS inventory_transfer_product_variant_fkey;


ALTER TABLE inventory_schema.inventory_transfer_product ADD CONSTRAINT inventory_transfer_product_variant_fkey
FOREIGN KEY (tenant_id,
             product_variant_id) REFERENCES general_schema.product_variant(tenant_id, product_variant_id) ON
DELETE CASCADE;

-- ─── discrepancy_count ──────────────────────────────────────────────────────

ALTER TABLE inventory_schema.discrepancy_count
DROP CONSTRAINT IF EXISTS discrepancy_count_product_variant_fkey;


ALTER TABLE inventory_schema.discrepancy_count ADD CONSTRAINT discrepancy_count_product_variant_fkey
FOREIGN KEY (tenant_id,
             product_variant_id) REFERENCES general_schema.product_variant(tenant_id, product_variant_id) ON
DELETE CASCADE;

-- inventory_transfer_request_product: already created with ON DELETE CASCADE
-- in migration inventory/032. No change needed.

COMMIT;