-- Migration 018: Add ON DELETE CASCADE to enable complete tenant deletion
--
-- Problem: Several HR and POS foreign keys lacked ON DELETE CASCADE, causing
-- FK violations when deleting a tenant. A single DELETE on general_schema.tenant
-- now propagates cleanly through every child table across all schemas.
--
-- Affected tables:
--   HR  → contract, turn, config, employee, foul, suspention, clocking,
--          tardiness, incapacity, payroll_concept, paysheet, paysheet_detail
--   POS → sale, electronic_sale_invoice_items
--
-- Strategy: DROP old constraint (if exists) → ADD with ON DELETE CASCADE.
-- Idempotent: safe to run multiple times.

-- ═══════════════════════════════════════════════════════════════════════════════
-- GENERAL SCHEMA
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── general_schema.users ──────────────────────────────────────────────────────
-- Ensure deleting a tenant removes all associated users.
ALTER TABLE general_schema.users
    DROP CONSTRAINT IF EXISTS users_tenant_id_fkey;
ALTER TABLE general_schema.users
    ADD CONSTRAINT users_tenant_id_fkey
    FOREIGN KEY (tenant_id) REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- HR SCHEMA
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── hr_schema.config (branch_id is also the PK) ──────────────────────────────
ALTER TABLE hr_schema.config
    DROP CONSTRAINT IF EXISTS config_branch_id_fkey;
ALTER TABLE hr_schema.config
    ADD CONSTRAINT config_branch_id_fkey
    FOREIGN KEY (branch_id) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

-- ── hr_schema.turn ───────────────────────────────────────────────────────────
ALTER TABLE hr_schema.turn
    DROP CONSTRAINT IF EXISTS turn_branch_id_fkey;
ALTER TABLE hr_schema.turn
    ADD CONSTRAINT turn_branch_id_fkey
    FOREIGN KEY (branch_id) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

-- ── hr_schema.contract ───────────────────────────────────────────────────────
ALTER TABLE hr_schema.contract
    DROP CONSTRAINT IF EXISTS contract_tenant_id_fkey;
ALTER TABLE hr_schema.contract
    ADD CONSTRAINT contract_tenant_id_fkey
    FOREIGN KEY (tenant_id) REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE;

ALTER TABLE hr_schema.contract
    DROP CONSTRAINT IF EXISTS contract_turn_id_fkey;
ALTER TABLE hr_schema.contract
    ADD CONSTRAINT contract_turn_id_fkey
    FOREIGN KEY (turn_id) REFERENCES hr_schema.turn(turn_id) ON DELETE CASCADE;

-- ── hr_schema.employee ───────────────────────────────────────────────────────
ALTER TABLE hr_schema.employee
    DROP CONSTRAINT IF EXISTS employee_tenant_id_fkey;
ALTER TABLE hr_schema.employee
    ADD CONSTRAINT employee_tenant_id_fkey
    FOREIGN KEY (tenant_id) REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE;

ALTER TABLE hr_schema.employee
    DROP CONSTRAINT IF EXISTS employee_branch_id_fkey;
ALTER TABLE hr_schema.employee
    ADD CONSTRAINT employee_branch_id_fkey
    FOREIGN KEY (branch_id) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

-- ── hr_schema.foul ───────────────────────────────────────────────────────────
ALTER TABLE hr_schema.foul
    DROP CONSTRAINT IF EXISTS foul_employee_id_fkey;
ALTER TABLE hr_schema.foul
    ADD CONSTRAINT foul_employee_id_fkey
    FOREIGN KEY (employee_id) REFERENCES hr_schema.employee(employee_id) ON DELETE CASCADE;

ALTER TABLE hr_schema.foul
    DROP CONSTRAINT IF EXISTS foul_branch_id_fkey;
ALTER TABLE hr_schema.foul
    ADD CONSTRAINT foul_branch_id_fkey
    FOREIGN KEY (branch_id) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

-- ── hr_schema.suspention ─────────────────────────────────────────────────────
ALTER TABLE hr_schema.suspention
    DROP CONSTRAINT IF EXISTS suspention_employee_id_fkey;
ALTER TABLE hr_schema.suspention
    ADD CONSTRAINT suspention_employee_id_fkey
    FOREIGN KEY (employee_id) REFERENCES hr_schema.employee(employee_id) ON DELETE CASCADE;

ALTER TABLE hr_schema.suspention
    DROP CONSTRAINT IF EXISTS suspention_branch_id_fkey;
ALTER TABLE hr_schema.suspention
    ADD CONSTRAINT suspention_branch_id_fkey
    FOREIGN KEY (branch_id) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

-- ── hr_schema.clocking ───────────────────────────────────────────────────────
ALTER TABLE hr_schema.clocking
    DROP CONSTRAINT IF EXISTS clocking_employee_id_fkey;
ALTER TABLE hr_schema.clocking
    ADD CONSTRAINT clocking_employee_id_fkey
    FOREIGN KEY (employee_id) REFERENCES hr_schema.employee(employee_id) ON DELETE CASCADE;

ALTER TABLE hr_schema.clocking
    DROP CONSTRAINT IF EXISTS clocking_branch_id_fkey;
ALTER TABLE hr_schema.clocking
    ADD CONSTRAINT clocking_branch_id_fkey
    FOREIGN KEY (branch_id) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

-- ── hr_schema.tardiness ──────────────────────────────────────────────────────
ALTER TABLE hr_schema.tardiness
    DROP CONSTRAINT IF EXISTS tardiness_employee_id_fkey;
ALTER TABLE hr_schema.tardiness
    ADD CONSTRAINT tardiness_employee_id_fkey
    FOREIGN KEY (employee_id) REFERENCES hr_schema.employee(employee_id) ON DELETE CASCADE;

ALTER TABLE hr_schema.tardiness
    DROP CONSTRAINT IF EXISTS tardiness_branch_id_fkey;
ALTER TABLE hr_schema.tardiness
    ADD CONSTRAINT tardiness_branch_id_fkey
    FOREIGN KEY (branch_id) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

-- ── hr_schema.incapacity ─────────────────────────────────────────────────────
ALTER TABLE hr_schema.incapacity
    DROP CONSTRAINT IF EXISTS incapacity_branch_id_fkey;
ALTER TABLE hr_schema.incapacity
    ADD CONSTRAINT incapacity_branch_id_fkey
    FOREIGN KEY (branch_id) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

ALTER TABLE hr_schema.incapacity
    DROP CONSTRAINT IF EXISTS incapacity_employee_id_fkey;
ALTER TABLE hr_schema.incapacity
    ADD CONSTRAINT incapacity_employee_id_fkey
    FOREIGN KEY (employee_id) REFERENCES hr_schema.employee(employee_id) ON DELETE CASCADE;

-- ── hr_schema.payroll_concept ────────────────────────────────────────────────
ALTER TABLE hr_schema.payroll_concept
    DROP CONSTRAINT IF EXISTS payroll_concept_tenant_id_fkey;
ALTER TABLE hr_schema.payroll_concept
    ADD CONSTRAINT payroll_concept_tenant_id_fkey
    FOREIGN KEY (tenant_id) REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE;

-- ── hr_schema.paysheet ───────────────────────────────────────────────────────
ALTER TABLE hr_schema.paysheet
    DROP CONSTRAINT IF EXISTS paysheet_tenant_id_fkey;
ALTER TABLE hr_schema.paysheet
    ADD CONSTRAINT paysheet_tenant_id_fkey
    FOREIGN KEY (tenant_id) REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE;

ALTER TABLE hr_schema.paysheet
    DROP CONSTRAINT IF EXISTS paysheet_branch_id_fkey;
ALTER TABLE hr_schema.paysheet
    ADD CONSTRAINT paysheet_branch_id_fkey
    FOREIGN KEY (branch_id) REFERENCES general_schema.branch(branch_id) ON DELETE CASCADE;

-- ── hr_schema.paysheet_detail ────────────────────────────────────────────────
ALTER TABLE hr_schema.paysheet_detail
    DROP CONSTRAINT IF EXISTS paysheet_detail_employee_id_fkey;
ALTER TABLE hr_schema.paysheet_detail
    ADD CONSTRAINT paysheet_detail_employee_id_fkey
    FOREIGN KEY (employee_id) REFERENCES hr_schema.employee(employee_id) ON DELETE CASCADE;

ALTER TABLE hr_schema.paysheet_detail
    DROP CONSTRAINT IF EXISTS paysheet_detail_contract_id_fkey;
ALTER TABLE hr_schema.paysheet_detail
    ADD CONSTRAINT paysheet_detail_contract_id_fkey
    FOREIGN KEY (contract_id) REFERENCES hr_schema.contract(contract_id) ON DELETE CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- POS SCHEMA
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── pos_schema.sale ──────────────────────────────────────────────────────────
-- tenant_customer_id is NOT NULL; when tenant_customer is deleted (via tenant
-- CASCADE), the sale must also be deleted to avoid a FK violation.
ALTER TABLE pos_schema.sale
    DROP CONSTRAINT IF EXISTS sale_tenant_customer_id_fkey;
ALTER TABLE pos_schema.sale
    ADD CONSTRAINT sale_tenant_customer_id_fkey
    FOREIGN KEY (tenant_customer_id)
    REFERENCES general_schema.tenant_customer(tenant_customer_id) ON DELETE CASCADE;

-- ── pos_schema.electronic_sale_invoice_items ─────────────────────────────────
-- sale_item cascades from sale → branch → tenant; this item must follow.
ALTER TABLE pos_schema.electronic_sale_invoice_items
    DROP CONSTRAINT IF EXISTS electronic_sale_invoice_items_sale_item_id_fkey;
ALTER TABLE pos_schema.electronic_sale_invoice_items
    ADD CONSTRAINT electronic_sale_invoice_items_sale_item_id_fkey
    FOREIGN KEY (sale_item_id) REFERENCES pos_schema.sale_item(sale_item_id) ON DELETE CASCADE;
