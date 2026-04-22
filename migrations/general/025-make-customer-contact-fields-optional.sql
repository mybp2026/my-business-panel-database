-- ======================================================
-- MIGRATION: general/025-make-customer-contact-fields-optional.sql
-- Makes email and phone optional in tenant_customer.
-- Not all customers have electronic invoicing or require
-- contact fields at the time of registration.
-- ======================================================

BEGIN;

ALTER TABLE general_schema.tenant_customer
    ALTER COLUMN email DROP NOT NULL;

ALTER TABLE general_schema.tenant_customer
    ALTER COLUMN phone DROP NOT NULL;

COMMIT;


-- ======================================================
-- ROLLBACK
-- ======================================================
-- BEGIN;
--
-- ALTER TABLE general_schema.tenant_customer
--     ALTER COLUMN email SET NOT NULL;
--
-- ALTER TABLE general_schema.tenant_customer
--     ALTER COLUMN phone SET NOT NULL;
--
-- COMMIT;
