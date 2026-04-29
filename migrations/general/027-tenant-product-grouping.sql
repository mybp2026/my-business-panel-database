-- ======================================================
-- MIGRATION: general/027-tenant-product-grouping.sql
-- Adds tenant-level product classification: dimensions
-- (Department, Family, Brand, ...), hierarchical group
-- nodes within each dimension, and an M2M assignment
-- table linking variants to groups across dimensions.
-- Independent from the global CABYS-derived
-- product_category catalog.
-- ======================================================

BEGIN;

-- 1. Classification dimensions (Department, Family, Brand, ...)
CREATE TABLE IF NOT EXISTS general_schema.tenant_product_group_type (
    tenant_product_group_type_id  uuid    NOT NULL DEFAULT gen_random_uuid(),
    tenant_id                     uuid    NOT NULL REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE,
    type_name                     VARCHAR(80) NOT NULL,
    description                   TEXT,
    is_active                     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at                    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, tenant_product_group_type_id),
    UNIQUE (tenant_id, type_name)
);

CREATE INDEX IF NOT EXISTS idx_tpgt_tenant
    ON general_schema.tenant_product_group_type(tenant_id);

-- 2. Hierarchical group nodes per dimension
CREATE TABLE IF NOT EXISTS general_schema.tenant_product_group (
    tenant_product_group_id       uuid    NOT NULL DEFAULT gen_random_uuid(),
    tenant_id                     uuid    NOT NULL,
    tenant_product_group_type_id  uuid    NOT NULL,
    parent_group_id               uuid,
    group_name                    VARCHAR(120) NOT NULL,
    hierarchy_level               INTEGER NOT NULL DEFAULT 0 CHECK (hierarchy_level >= 0),
    is_active                     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at                    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, tenant_product_group_id),
    FOREIGN KEY (tenant_id, tenant_product_group_type_id)
        REFERENCES general_schema.tenant_product_group_type(tenant_id, tenant_product_group_type_id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, parent_group_id)
        REFERENCES general_schema.tenant_product_group(tenant_id, tenant_product_group_id) ON DELETE CASCADE,
    CHECK (parent_group_id IS NULL OR parent_group_id <> tenant_product_group_id),
    UNIQUE (tenant_id, tenant_product_group_type_id, parent_group_id, group_name)
);

CREATE INDEX IF NOT EXISTS idx_tpg_parent
    ON general_schema.tenant_product_group(tenant_id, parent_group_id) WHERE parent_group_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tpg_type
    ON general_schema.tenant_product_group(tenant_id, tenant_product_group_type_id);

-- 3. Variant <-> Group M2M (variant can be in groups of multiple dimensions)
CREATE TABLE IF NOT EXISTS general_schema.product_variant_group_assignment (
    tenant_id                  uuid NOT NULL,
    product_variant_id         uuid NOT NULL,
    tenant_product_group_id    uuid NOT NULL,
    created_at                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, product_variant_id, tenant_product_group_id),
    FOREIGN KEY (tenant_id, product_variant_id)
        REFERENCES general_schema.product_variant(tenant_id, product_variant_id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, tenant_product_group_id)
        REFERENCES general_schema.tenant_product_group(tenant_id, tenant_product_group_id) ON DELETE CASCADE
) PARTITION BY HASH (tenant_id);

DO $$ DECLARE i INT; BEGIN
  FOR i IN 0..7 LOOP
    EXECUTE format(
      'CREATE TABLE IF NOT EXISTS general_schema.product_variant_group_assignment_p%s
       PARTITION OF general_schema.product_variant_group_assignment
       FOR VALUES WITH (MODULUS 8, REMAINDER %s);', i, i);
  END LOOP;
END $$ LANGUAGE plpgsql;

CREATE INDEX IF NOT EXISTS idx_pvga_group
    ON general_schema.product_variant_group_assignment(tenant_id, tenant_product_group_id);

COMMIT;


-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
--
-- DROP TABLE IF EXISTS general_schema.product_variant_group_assignment CASCADE;
-- DROP TABLE IF EXISTS general_schema.tenant_product_group CASCADE;
-- DROP TABLE IF EXISTS general_schema.tenant_product_group_type CASCADE;
--
-- COMMIT;
