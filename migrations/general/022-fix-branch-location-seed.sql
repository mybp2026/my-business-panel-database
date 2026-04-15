-- ======================================================
-- MIGRATION: general/022-fix-branch-location-seed.sql
-- ======================================================
-- Fix: migration 012 had a hardcoded branch_id INSERT that fails
-- when that branch doesn't exist. This replaces it with a
-- conditional insert that only runs if the branch is present.

BEGIN;

-- Only insert the seed location if the branch actually exists
INSERT INTO general_schema.branch_location (branch_id, provincia, canton, distrito, otras_senas)
SELECT '859cc745-185e-4af3-82fc-9c5b8d6e6f26', '4', '09', '01', 'Calle Principal 123, San José, Costa Rica'
WHERE EXISTS (SELECT 1 FROM general_schema.branch WHERE branch_id = '859cc745-185e-4af3-82fc-9c5b8d6e6f26')
ON CONFLICT (branch_id) DO NOTHING;

-- Only update econ_activity if the branch actually exists
UPDATE general_schema.branch
SET econ_activity = '620100'
WHERE branch_id = '859cc745-185e-4af3-82fc-9c5b8d6e6f26';

COMMIT;
