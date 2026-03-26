-- Migration 016: Add tax_regime to tenant table
-- Differentiates tenants under the traditional (régimen tradicional)
-- vs. simplified (régimen simplificado) Costa Rican tax scheme.
-- Idempotent: safe to run multiple times.

SET SEARCH_PATH TO general_schema;

-- Step 1: Create ENUM type if it doesn't exist
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type
        WHERE typname = 'tax_regime'
          AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'general_schema')
    ) THEN
        CREATE TYPE general_schema.tax_regime AS ENUM ('traditional', 'simplified');
    END IF;
END $$;

-- Step 2: Add column if it doesn't exist
ALTER TABLE general_schema.tenant
    ADD COLUMN IF NOT EXISTS tax_regime general_schema.tax_regime NOT NULL DEFAULT 'traditional';

COMMENT ON COLUMN general_schema.tenant.tax_regime IS
    'Tenant tax regime: traditional (régimen general IVA) or simplified (régimen simplificado, Decreto 38 MH).';
