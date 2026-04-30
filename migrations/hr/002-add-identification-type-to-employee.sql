-- ============================================================
-- Migration HR-002: identification_type_id on employee
-- ------------------------------------------------------------
--   Adds an FK to general_schema.identification_type so each
--   employee has an explicit document type (Cédula Física, DIMEX,
--   etc.). Also rebuilds hr_schema.create_new_employee to accept
--   the new column.
-- ============================================================

BEGIN;

ALTER TABLE hr_schema.employee
    ADD COLUMN IF NOT EXISTS identification_type_id INTEGER
        REFERENCES general_schema.identification_type(identification_type_id)
        ON DELETE SET NULL;

-- Backfill: existing employees default to "Cédula Física" (id 1) when null.
UPDATE hr_schema.employee
SET identification_type_id = 1
WHERE identification_type_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_employee_identification_type
    ON hr_schema.employee(identification_type_id);

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
    p_identification_type_id INTEGER DEFAULT 1
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

    INSERT INTO hr_schema.contract (tenant_id, start_date, end_date, hours, base_salary, duties, turn_type, turn_id)
    VALUES (p_tenant_id, p_start_date, p_end_date, p_hours, p_base_salary, p_duties, p_turn_type, p_turn_id)
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
        RAISE EXCEPTION 'Integrity Error: Insert failed, cause of the error a non existent FOREIGN KEY (user_id, payment_schedule_id, or identification_type_id).';
    WHEN others THEN
        RAISE EXCEPTION 'Error creating employee or contract: %', SQLERRM;
END;
$function$;

COMMIT;
