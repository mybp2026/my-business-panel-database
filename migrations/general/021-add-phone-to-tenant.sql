-- Migration 021: Add contact_phone to tenant and country_code to region
-- Adds phone field to tenant, phone codes to region, and inserts Spain
-- Idempotent: safe to run multiple times.

SET SEARCH_PATH TO general_schema;

-- 1. Add country_code column to region table
ALTER TABLE IF EXISTS region
ADD COLUMN IF NOT EXISTS country_code VARCHAR(5);

-- 2. Update existing regions with their country codes
UPDATE region SET country_code = '+506' WHERE region_name = 'Costa Rica' AND country_code IS NULL;
UPDATE region SET country_code = '+507' WHERE region_name = 'Panama' AND country_code IS NULL;
UPDATE region SET country_code = '+1' WHERE region_name = 'United States' AND country_code IS NULL;
UPDATE region SET country_code = '+44' WHERE region_name = 'United Kingdom' AND country_code IS NULL;
UPDATE region SET country_code = '+81' WHERE region_name = 'Japan' AND country_code IS NULL;

-- 3. Insert Spain with country code
INSERT INTO region (region_name, country_code)
VALUES ('Spain', '+34')
ON CONFLICT (region_name) DO NOTHING;

-- 4. Add contact_phone column to tenant
ALTER TABLE IF EXISTS tenant
ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(20);

-- Comments
COMMENT ON COLUMN region.country_code IS 'International dialing code (e.g., +506 for Costa Rica)';
COMMENT ON COLUMN tenant.contact_phone IS 'Contact phone number for the tenant (in international format)';
