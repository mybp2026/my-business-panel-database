-- ============================================================
-- Migration general-030: special_code (onboarding bypass)
-- ------------------------------------------------------------
--   Tabla de códigos especiales que el superusuario puede emitir
--   para que ciertos clientes se registren sin pagar Stripe en el
--   paso 4 del onboarding. Cada código se canjea una sola vez:
--   la transacción de onboarding marca is_used = TRUE y graba el
--   tenant_id que lo consumió.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS general_schema.special_code (
    special_code_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(64) UNIQUE NOT NULL,
    description TEXT,
    -- FK al superusuario que creó el código (auditoría).
    created_by UUID REFERENCES general_schema.users(user_id) ON DELETE SET NULL,
    -- Marcado en TRUE durante el onboarding cuando alguien lo canjea.
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    -- Tenant que se registró usando el código. Permanece NULL hasta el canje.
    tenant_id UUID REFERENCES general_schema.tenant(tenant_id) ON DELETE SET NULL,
    used_at TIMESTAMP,
    expires_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Si el código está consumido tiene que tener tenant + fecha; si no
    -- está consumido, los dos campos deben ser NULL. Garantiza la
    -- semántica "se usa una sola vez".
    CONSTRAINT special_code_used_consistency
        CHECK (
            (is_used = FALSE AND tenant_id IS NULL AND used_at IS NULL) OR
            (is_used = TRUE  AND tenant_id IS NOT NULL AND used_at IS NOT NULL)
        )
);

-- Búsquedas frecuentes: el lookup por código durante onboarding y los
-- listados que filtran por estado consumido / no consumido.
CREATE UNIQUE INDEX IF NOT EXISTS idx_special_code_code
    ON general_schema.special_code(code);
CREATE INDEX IF NOT EXISTS idx_special_code_is_used
    ON general_schema.special_code(is_used);
CREATE INDEX IF NOT EXISTS idx_special_code_tenant
    ON general_schema.special_code(tenant_id)
    WHERE tenant_id IS NOT NULL;

COMMENT ON TABLE general_schema.special_code IS
    'Códigos de un solo uso que el superusuario emite para permitir registro sin pago en el onboarding.';
COMMENT ON COLUMN general_schema.special_code.is_used IS
    'TRUE cuando un onboarding consumió el código. Inmutable después de TRUE (un código no se puede reciclar).';
COMMENT ON COLUMN general_schema.special_code.tenant_id IS
    'Tenant creado durante el onboarding que canjeó este código. NULL mientras esté disponible.';

COMMIT;

-- -----------------
-- ROLLBACK
-- -----------------
/*
BEGIN;
DROP TABLE IF EXISTS general_schema.special_code;
COMMIT;
*/

INSERT INTO general_schema.special_code (code, description, created_by, expires_at)
VALUES ('ONBOARDING_BYPASS', 'Código especial para permitir que ciertos clientes se registren sin pagar Stripe durante el onboarding. Emitido por el superusuario y canjeable una sola vez.', NULL, CURRENT_DATE + INTERVAL '1 year')
ON CONFLICT (code) DO NOTHING;
