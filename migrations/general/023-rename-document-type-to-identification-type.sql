-- ======================================================
-- MIGRATION: general/023-rename-document-type-to-identification-type.sql
-- Renames the document_type table to identification_type and updates
-- all dependent database objects:
--   - PK constraint on identification_type
--   - UNIQUE constraint on identification_type
--   - FK column + constraint on tenant_customer
-- ======================================================

BEGIN;

-- ── 1. Rename the table ────────────────────────────────────────────────────
ALTER TABLE general_schema.document_type
    RENAME TO identification_type;

-- ── 2. Rename the primary key column ──────────────────────────────────────
ALTER TABLE general_schema.identification_type
    RENAME COLUMN document_type_id TO identification_type_id;

-- ── 3. Rename auto-generated PK constraint ────────────────────────────────
--  PostgreSQL default name: document_type_pkey
ALTER TABLE general_schema.identification_type
    RENAME CONSTRAINT document_type_pkey TO identification_type_pkey;

-- ── 4. Rename auto-generated UNIQUE constraint on type_name ───────────────
--  PostgreSQL default name: document_type_type_name_key
ALTER TABLE general_schema.identification_type
    RENAME CONSTRAINT document_type_type_name_key TO identification_type_type_name_key;

-- ── 5. Drop FK from tenant_customer that referenced the old table/column ──
--  PostgreSQL default name: tenant_customer_document_type_id_fkey
ALTER TABLE general_schema.tenant_customer
    DROP CONSTRAINT tenant_customer_document_type_id_fkey;

-- ── 6. Rename FK column in tenant_customer ────────────────────────────────
ALTER TABLE general_schema.tenant_customer
    RENAME COLUMN document_type_id TO identification_type_id;

-- ── 7. Re-create FK with updated name and reference ───────────────────────
ALTER TABLE general_schema.tenant_customer
    ADD CONSTRAINT tenant_customer_identification_type_id_fkey
    FOREIGN KEY (identification_type_id)
    REFERENCES general_schema.identification_type(identification_type_id)
    ON DELETE SET NULL;

COMMIT;


-- ======================================================
-- ROLLBACK — ejecutar si hay breaking errors
-- ======================================================
-- BEGIN;
--
-- -- 7. Drop nueva FK
-- ALTER TABLE general_schema.tenant_customer
--     DROP CONSTRAINT tenant_customer_identification_type_id_fkey;
--
-- -- 6. Revertir nombre de columna en tenant_customer
-- ALTER TABLE general_schema.tenant_customer
--     RENAME COLUMN identification_type_id TO document_type_id;
--
-- -- 5. Recrear FK original
-- ALTER TABLE general_schema.tenant_customer
--     ADD CONSTRAINT tenant_customer_document_type_id_fkey
--     FOREIGN KEY (document_type_id)
--     REFERENCES general_schema.identification_type(identification_type_id)
--     ON DELETE SET NULL;
--
-- -- 4. Revertir UNIQUE constraint
-- ALTER TABLE general_schema.identification_type
--     RENAME CONSTRAINT identification_type_type_name_key TO document_type_type_name_key;
--
-- -- 3. Revertir PK constraint
-- ALTER TABLE general_schema.identification_type
--     RENAME CONSTRAINT identification_type_pkey TO document_type_pkey;
--
-- -- 2. Revertir nombre de columna PK
-- ALTER TABLE general_schema.identification_type
--     RENAME COLUMN identification_type_id TO document_type_id;
--
-- -- 1. Revertir nombre de tabla
-- ALTER TABLE general_schema.identification_type
--     RENAME TO document_type;
--
-- COMMIT;
