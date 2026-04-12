-- Migration 017: Replace multi-tier subscription plans with a single plan
-- Previous plans (Basic/Standard/Premium) are removed and replaced by
-- "Plan Completo" at $99.99/month with full platform access.
-- Idempotent: safe to run multiple times.

SET search_path TO general_schema;

DO $$
DECLARE
fk_name text;
BEGIN
SELECT tc.constraint_name
INTO fk_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
ON tc.constraint_name = kcu.constraint_name
AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'general_schema'
AND tc.table_name = 'subscription'
AND tc.constraint_type = 'FOREIGN KEY'
AND kcu.column_name = 'subscription_type_id'
LIMIT 1;

IF fk_name IS NOT NULL THEN
EXECUTE format(
'ALTER TABLE general_schema.subscription DROP CONSTRAINT %I',
fk_name
);
END IF;
END $$;

ALTER TABLE general_schema.subscription
ADD CONSTRAINT subscription_subscription_type_id_fkey
FOREIGN KEY (subscription_type_id)
REFERENCES general_schema.subscription_type(subscription_type_id)
ON DELETE CASCADE;

-- Step 1: Remove legacy plans
DELETE FROM general_schema.subscription_type;

-- Step 2: Insert new plan with explicit ID 1
INSERT INTO general_schema.subscription_type (
    subscription_type_id,
    subscription_type_name,
    subscription_type_detail,
    duration_months,
    subscription_type_cost
)
VALUES (
    1,
    'Plan Completo',
    'Acceso total a la plataforma',
    1,
    99.99
)
ON CONFLICT (subscription_type_id) DO UPDATE SET
    subscription_type_name = EXCLUDED.subscription_type_name,
    subscription_type_detail = EXCLUDED.subscription_type_detail,
    subscription_type_cost = EXCLUDED.subscription_type_cost;

-- Step 3: Reset the sequence
SELECT setval(
    pg_get_serial_sequence('general_schema.subscription_type', 'subscription_type_id'),
    COALESCE((SELECT MAX(subscription_type_id) FROM general_schema.subscription_type), 1),
    true
);

