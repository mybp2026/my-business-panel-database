-- ======================================================
-- MIGRATION: hr/005-add-duties-type-catalog.sql
-- ======================================================
-- Author: David
-- Date: 2026-05-11
-- Description: Introduces hr_schema.duties_type as a per-tenant catalog
--   table for employee job functions/roles. Adds duties_type_id FK on
--   hr_schema.contract replacing the free-text duties field for new
--   records. The legacy duties TEXT column is preserved as nullable for
--   backward compatibility with existing data.
-- Dependencies: hr_schema initial setup
-- Breaking Changes: NO (additive only)
-- Rollback: See bottom of file
-- ======================================================

BEGIN;

CREATE TABLE IF NOT EXISTS hr_schema.duties_type (
    duties_type_id SERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_duties_type_tenant ON hr_schema.duties_type(tenant_id);

ALTER TABLE hr_schema.contract
    ADD COLUMN IF NOT EXISTS duties_type_id INTEGER REFERENCES hr_schema.duties_type(duties_type_id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION hr_schema.create_new_employee(
    p_start_date DATE,
    p_end_date DATE,
    p_hours INTEGER,
    p_base_salary NUMERIC,
    p_duties TEXT,
    p_turn_type INTEGER,
    p_turn_id INTEGER,
    p_user_id UUID,
    p_tenant_id UUID,
    p_first_name CHARACTER VARYING,
    p_last_name CHARACTER VARYING,
    p_doc_number CHARACTER VARYING,
    p_phone CHARACTER VARYING,
    p_email CHARACTER VARYING,
    p_payment_schedule_id INTEGER,
    p_branch_id UUID,
    p_identification_type_id INTEGER DEFAULT 1,
    p_duties_type_id INTEGER DEFAULT NULL
  )
 RETURNS UUID
 LANGUAGE plpgsql
AS $function$

DECLARE
  v_new_contract_id UUID;
  v_new_employee_id UUID;
BEGIN

  IF NOT EXISTS (SELECT 1 FROM hr_schema.payment_schedule WHERE payment_schedule_id = p_payment_schedule_id) THEN
    RAISE EXCEPTION 'Integrity error: payment_schedule_id (payment_schedule_id: %) doesnt exists', p_payment_schedule_id;
  END IF;

  INSERT INTO hr_schema.contract (tenant_id, start_date, end_date, hours, base_salary, duties, turn_type, turn_id, duties_type_id)
  VALUES (p_tenant_id, p_start_date, p_end_date, p_hours, p_base_salary, p_duties, p_turn_type, p_turn_id, p_duties_type_id)
  RETURNING contract_id INTO v_new_contract_id;

  v_new_employee_id := gen_random_uuid();

  INSERT INTO hr_schema.employee (
    employee_id, user_id, first_name, last_name, doc_number,
    identification_type_id, phone, email, contract_id,
    payment_schedule_id, tenant_id, branch_id
  )
  VALUES (
    v_new_employee_id,
    p_user_id,
    p_first_name,
    p_last_name,
    p_doc_number,
    p_identification_type_id,
    p_phone,
    p_email,
    v_new_contract_id,
    p_payment_schedule_id,
    p_tenant_id,
    p_branch_id
  );

  RETURN v_new_employee_id;

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Data Error: Document Number (%) or Email already exists.', p_doc_number;
  WHEN foreign_key_violation THEN
    RAISE EXCEPTION 'Integrity Error: Insert failed due to a non-existent FOREIGN KEY (payment_schedule_id, identification_type_id, or duties_type_id).';
  WHEN others THEN
    RAISE EXCEPTION 'Error creating employee or contract: %', SQLERRM;
END;
$function$;

COMMIT;

-- ======================================================
-- ROLLBACK (run manually if needed):
-- ======================================================
-- BEGIN;
-- ALTER TABLE hr_schema.contract DROP COLUMN IF EXISTS duties_type_id;
-- DROP TABLE IF EXISTS hr_schema.duties_type;
-- COMMIT;
