-- ======================================================
-- SEED: 013-insert-products.sql
-- ======================================================
-- Description: Loads CABYS product catalog into
--              general_schema.product from CSV.
--
-- Uses a temp table to skip the GENERATED column
-- product_name_tsv (auto-computed by PostgreSQL).
--
-- The tax_rate_id in the CSV was generated against a
-- specific historical DB state. This seed resolves the
-- correct tax_rate_id dynamically by rate_percentage:
--   CSV ID 7  → 13%
--   CSV ID 8  →  0% (exento)
--   CSV ID 9  → 13% (best estimate, 21 products)
--   CSV ID 10 →  1%
--   CSV ID 11 → 13% (best estimate, 32 products)
--   CSV ID 12 →  4%
--   CSV ID 13 →  2%
--
-- CSV header:
--   cabys_code, product_name, product_name_tsv,
--   product_category_id, tax_rate_id, unit_measure_id,
--   commercial_unit_measure_id, is_exonerated,
--   created_at, updated_at
--
-- NOTE: Must be run from the my-business-panel-database/ directory.
-- ======================================================

CREATE TEMP TABLE tmp_product_import (
    cabys_code                  VARCHAR(13),
    product_name                TEXT,
    product_name_tsv            TEXT,
    product_category_id         VARCHAR(13),
    old_tax_rate_id             INT,
    unit_measure_id             INT,
    commercial_unit_measure_id  INT,
    is_exonerated               TEXT,
    created_at                  TIMESTAMP,
    updated_at                  TIMESTAMP
);

\copy tmp_product_import FROM 'seeds/catalog/general/product.csv' WITH (FORMAT CSV, HEADER true, NULL 'NULL', ENCODING 'UTF8');

INSERT INTO general_schema.product (
    cabys_code,
    product_name,
    product_category_id,
    tax_rate_id,
    unit_measure_id,
    commercial_unit_measure_id,
    is_exonerated,
    created_at,
    updated_at
)
SELECT
    cabys_code,
    product_name,
    product_category_id,
    CASE old_tax_rate_id
        WHEN 7  THEN (SELECT tax_rate_id FROM general_schema.tax_rate WHERE rate_percentage = 13.00 AND region LIKE 'CR%' LIMIT 1)
        WHEN 8  THEN (SELECT tax_rate_id FROM general_schema.tax_rate WHERE rate_percentage =  0.00 LIMIT 1)
        WHEN 9  THEN (SELECT tax_rate_id FROM general_schema.tax_rate WHERE rate_percentage = 13.00 AND region LIKE 'CR%' LIMIT 1)
        WHEN 10 THEN (SELECT tax_rate_id FROM general_schema.tax_rate WHERE rate_percentage =  1.00 AND region LIKE 'CR%' LIMIT 1)
        WHEN 11 THEN (SELECT tax_rate_id FROM general_schema.tax_rate WHERE rate_percentage = 13.00 AND region LIKE 'CR%' LIMIT 1)
        WHEN 12 THEN (SELECT tax_rate_id FROM general_schema.tax_rate WHERE rate_percentage =  4.00 AND region LIKE 'CR%' LIMIT 1)
        WHEN 13 THEN (SELECT tax_rate_id FROM general_schema.tax_rate WHERE rate_percentage =  2.00 AND region LIKE 'CR%' LIMIT 1)
        ELSE NULL
    END AS tax_rate_id,
    unit_measure_id,
    commercial_unit_measure_id,
    lower(is_exonerated)::boolean,
    created_at,
    updated_at
FROM tmp_product_import;

DROP TABLE tmp_product_import;
