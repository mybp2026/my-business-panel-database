-- ======================================================
-- SEED: 012-insert-product-categories.sql
-- ======================================================
-- Description: Loads CABYS product category catalog into
--              general_schema.product_category from CSV.
--
-- Uses a temp table and inserts ordered by code length so
-- parents are always inserted before their children,
-- satisfying the self-referential FK constraint.
-- Triggers are disabled during bulk load (data already
-- contains pre-computed hierarchy_level values).
--
-- CSV format (no header):
--   product_category_id, category_name, parent_category_id,
--   hierarchy_level, created_at, updated_at
--
-- NOTE: Must be run from the my-business-panel-database/ directory.
-- ======================================================

ALTER TABLE general_schema.product_category DISABLE TRIGGER ALL;

CREATE TEMP TABLE tmp_category_import (
    product_category_id VARCHAR(13),
    category_name       TEXT,
    parent_category_id  VARCHAR(13),
    hierarchy_level     INT,
    created_at          TIMESTAMP,
    updated_at          TIMESTAMP
);

\copy tmp_category_import FROM 'seeds/catalog/general/product_category.csv' WITH (FORMAT CSV, NULL '', ENCODING 'UTF8');

INSERT INTO general_schema.product_category (product_category_id, category_name, parent_category_id, hierarchy_level, created_at, updated_at)
SELECT product_category_id, category_name, parent_category_id, hierarchy_level, created_at, updated_at
FROM tmp_category_import
ORDER BY length(product_category_id), product_category_id;

DROP TABLE tmp_category_import;

ALTER TABLE general_schema.product_category ENABLE TRIGGER ALL;
