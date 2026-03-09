-- ======================================================
-- MIGRATION: general/011-tenant-location.sql
-- ======================================================
-- Description: Adds general_schema.tenant_location table to store
--   structured address data needed for Costa Rica electronic invoicing
--   (provincia, canton, distrito, otras_senas per DGT-R-48-2016).
--
-- This table is LEFT-JOINed in getSaleForElectronicInvoice; tenants
-- without a row return empty-string fallbacks until their data is filled.
-- ======================================================

BEGIN;

CREATE TABLE IF NOT EXISTS general_schema.tenant_location (
    tenant_location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- One location row per tenant (1-to-1)
    tenant_id UUID NOT NULL UNIQUE REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE,

    -- Costa Rica administrative divisions (Hacienda DGT-R-48-2016)
    provincia  VARCHAR(1)   NOT NULL DEFAULT '1',   -- 1=San José … 7=Limón
    canton     VARCHAR(2)   NOT NULL DEFAULT '01',
    distrito   VARCHAR(2)   NOT NULL DEFAULT '01',
    otras_senas TEXT        NOT NULL DEFAULT '',

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP          DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tenant_location_tenant_id
    ON general_schema.tenant_location(tenant_id);

CREATE TRIGGER update_tenant_location_timestamp
    BEFORE UPDATE ON general_schema.tenant_location
    FOR EACH ROW EXECUTE FUNCTION general_schema.update_timestamp();

COMMIT;

-- ROLLBACK:
-- BEGIN;
-- DROP TABLE IF EXISTS general_schema.tenant_location CASCADE;
-- COMMIT;
