-- ======================================================
-- MIGRATION: general/024-add-identification-type-to-tenant.sql
-- Adds identification_type_id FK to tenant table and backfills
-- existing records based on the identification field format.
--
-- Heuristics used (Costa Rica):
--   9 digits            → Cédula Física    (01)
--   10 digits, starts 3 → Cédula Jurídica  (02)
--   11–12 digits        → DIMEX            (03)
--   10 digits, other    → NITE             (04)
-- ======================================================

BEGIN;

-- ── 1. Add nullable column ─────────────────────────────────────────────────
ALTER TABLE general_schema.tenant
    ADD COLUMN IF NOT EXISTS identification_type_id INTEGER
        REFERENCES general_schema.identification_type(identification_type_id)
        ON DELETE SET NULL;

-- ── 2. Backfill existing records ───────────────────────────────────────────
-- Cédula Física: exactly 9 numeric digits
UPDATE general_schema.tenant t
SET identification_type_id = (
    SELECT identification_type_id
    FROM general_schema.identification_type
    WHERE ident_code = '01'
)
WHERE t.identification ~ '^[0-9]{9}$';

-- Cédula Jurídica: exactly 10 numeric digits starting with 3
UPDATE general_schema.tenant t
SET identification_type_id = (
    SELECT identification_type_id
    FROM general_schema.identification_type
    WHERE ident_code = '02'
)
WHERE t.identification ~ '^3[0-9]{9}$';

-- DIMEX: 11 or 12 numeric digits
UPDATE general_schema.tenant t
SET identification_type_id = (
    SELECT identification_type_id
    FROM general_schema.identification_type
    WHERE ident_code = '03'
)
WHERE t.identification ~ '^[0-9]{11,12}$';

-- NITE: exactly 10 numeric digits NOT starting with 3
UPDATE general_schema.tenant t
SET identification_type_id = (
    SELECT identification_type_id
    FROM general_schema.identification_type
    WHERE ident_code = '04'
)
WHERE t.identification ~ '^[0-9]{10}$'
  AND t.identification !~ '^3';

COMMIT;


-- ======================================================
-- ROLLBACK — ejecutar si hay breaking errors
-- ======================================================
-- BEGIN;
--
-- ALTER TABLE general_schema.tenant
--     DROP COLUMN IF EXISTS identification_type_id;
--
-- COMMIT;
