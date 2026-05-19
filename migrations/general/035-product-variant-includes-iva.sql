-- Agrega columna includes_iva a product_variant.
-- Indica si el precio de venta ya incluye IVA (true) o si el IVA debe calcularse sobre el precio (false).
-- Valor false por defecto: preserva comportamiento actual (IVA se aplica sobre el precio).

ALTER TABLE general_schema.product_variant
    ADD COLUMN IF NOT EXISTS includes_iva BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN general_schema.product_variant.includes_iva IS
    'true = el precio unitario ya incluye IVA; false = el IVA se calcula sobre el precio de venta.';

-- ROLLBACK:
-- ALTER TABLE general_schema.product_variant DROP COLUMN IF EXISTS includes_iva;
