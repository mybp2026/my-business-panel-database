-- Migration 020: Add tenant_hacienda_config table
-- Stores per-tenant Hacienda credentials (ATV) for electronic invoicing.
-- All sensitive fields are stored encrypted (AES-256-GCM) at application level.
-- Idempotent: safe to run multiple times.

SET SEARCH_PATH TO general_schema;

CREATE TABLE IF NOT EXISTS tenant_hacienda_config (
    tenant_hacienda_config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL UNIQUE REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE,
    hacienda_username TEXT NOT NULL,
    hacienda_password TEXT NOT NULL,
    hacienda_client_id VARCHAR(20) NOT NULL DEFAULT 'api-prod',
    p12_base64 TEXT NOT NULL,
    p12_password TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tenant_hacienda_config_tenant
    ON general_schema.tenant_hacienda_config(tenant_id);

COMMENT ON TABLE general_schema.tenant_hacienda_config IS
    'Per-tenant Hacienda (ATV) credentials for electronic invoicing. All credential fields are AES-256-GCM encrypted at application level.';