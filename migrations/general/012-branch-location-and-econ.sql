-- ======================================================
-- MIGRATION: general/012-branch-location-and-econ.sql
-- ======================================================

BEGIN;

-- Add econ_activity to branch table
ALTER TABLE general_schema.branch ADD COLUMN IF NOT EXISTS econ_activity VARCHAR(10);

-- Migrate tenant_location to branch_location
-- 1. Add branch_id column temporarily to map the data
ALTER TABLE general_schema.tenant_location ADD COLUMN branch_id UUID;

-- 2. Map existing data to point to the main branch of that tenant
UPDATE general_schema.tenant_location tl
SET branch_id = (
    SELECT branch_id FROM general_schema.branch b 
    WHERE b.tenant_id = tl.tenant_id 
    ORDER BY b.is_main_branch DESC LIMIT 1
);

-- Delete locations where we couldn't find a corresponding branch
DELETE FROM general_schema.tenant_location WHERE branch_id IS NULL;

-- 3. Drop constraints on tenant_location safely
ALTER TABLE general_schema.tenant_location DROP CONSTRAINT IF EXISTS tenant_location_tenant_id_key;
ALTER TABLE general_schema.tenant_location DROP CONSTRAINT IF EXISTS tenant_location_tenant_id_fkey;
DROP INDEX IF EXISTS general_schema.idx_tenant_location_tenant_id;

-- 4. Drop tenant_id
ALTER TABLE general_schema.tenant_location DROP COLUMN IF EXISTS tenant_id;

-- 5. Rename table to branch_location
ALTER TABLE general_schema.tenant_location RENAME TO branch_location;

-- 6. Rename primary key column
ALTER TABLE general_schema.branch_location RENAME COLUMN tenant_location_id TO branch_location_id;

-- 7. Configure new branch_id constraints
ALTER TABLE general_schema.branch_location ALTER COLUMN branch_id SET NOT NULL;
ALTER TABLE general_schema.branch_location ADD CONSTRAINT unique_branch_location_branch_id UNIQUE (branch_id);
ALTER TABLE general_schema.branch_location ADD CONSTRAINT branch_location_branch_id_fkey 
    FOREIGN KEY (branch_id) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_branch_location_branch_id
    ON general_schema.branch_location(branch_id);

-- Seed data moved to 022-fix-branch-location-seed.sql (conditional insert)

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- ALTER TABLE general_schema.branch_location RENAME TO tenant_location;
-- ALTER TABLE general_schema.tenant_location RENAME COLUMN branch_location_id TO tenant_location_id;
-- ALTER TABLE general_schema.tenant_location ADD COLUMN tenant_id UUID;
-- UPDATE general_schema.tenant_location tl SET tenant_id = (SELECT tenant_id FROM general_schema.branch b WHERE b.branch_id = tl.branch_id LIMIT 1);
-- ALTER TABLE general_schema.tenant_location DROP COLUMN branch_id;
-- ALTER TABLE general_schema.tenant_location ALTER COLUMN tenant_id SET NOT NULL;
-- ALTER TABLE general_schema.tenant_location ADD CONSTRAINT tenant_location_tenant_id_key UNIQUE (tenant_id);
-- ALTER TABLE general_schema.tenant_location ADD CONSTRAINT tenant_location_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE;
-- CREATE INDEX idx_tenant_location_tenant_id ON general_schema.tenant_location(tenant_id);
-- ALTER TABLE general_schema.branch DROP COLUMN IF EXISTS econ_activity;
-- COMMIT;
