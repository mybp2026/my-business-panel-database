-- ============================================================
-- Migration 015: Expense Management System
-- Phase 3 - Gastos Operativos
-- ============================================================
-- Adds expense_category, expense, and fiscal_period tables
-- to accounting_schema for operational expense tracking
-- and period-based financial reporting.
-- ============================================================

BEGIN;

-- -------------------------------------------------------
-- 1. EXPENSE CATEGORY
-- -------------------------------------------------------
-- Maps expense types to chart of accounts codes.
-- is_fixed distinguishes between fixed and variable expenses.

CREATE TABLE IF NOT EXISTS accounting_schema.expense_category (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    account_code VARCHAR(20) NOT NULL,
    parent_category_id UUID REFERENCES accounting_schema.expense_category(category_id) ON DELETE SET NULL,
    is_fixed BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(tenant_id, name),
    CONSTRAINT chk_no_self_parent_cat CHECK (category_id != parent_category_id)
);

CREATE INDEX IF NOT EXISTS idx_expense_cat_tenant
    ON accounting_schema.expense_category(tenant_id);
CREATE INDEX IF NOT EXISTS idx_expense_cat_active
    ON accounting_schema.expense_category(tenant_id, is_active)
    WHERE is_active = TRUE;

COMMENT ON TABLE accounting_schema.expense_category IS
    'Expense categories that map to chart of accounts codes. is_fixed=TRUE for recurring/fixed expenses, FALSE for variable.';
COMMENT ON COLUMN accounting_schema.expense_category.account_code IS
    'References chart_of_accounts.account_code for the tenant. Used to resolve the debit account in journal entries.';

-- -------------------------------------------------------
-- 2. EXPENSE
-- -------------------------------------------------------
-- Individual expense records linked to a category, branch, and tenant.

CREATE TABLE IF NOT EXISTS accounting_schema.expense (
    expense_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES general_schema.branch(branch_id),
    category_id UUID NOT NULL REFERENCES accounting_schema.expense_category(category_id),
    description TEXT,
    amount NUMERIC(14,4) NOT NULL CHECK (amount > 0),
    tax_amount NUMERIC(14,4) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    total_amount NUMERIC(14,4) NOT NULL CHECK (total_amount > 0),
    currency_id INTEGER NOT NULL REFERENCES general_schema.currency(currency_id),
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_method VARCHAR(20) NOT NULL DEFAULT 'CASH'
        CHECK (payment_method IN ('CASH', 'BANK', 'CREDIT_CARD', 'CHECK', 'TRANSFER')),
    reference_number VARCHAR(50),
    notes TEXT,
    created_by UUID REFERENCES general_schema.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_expense_tenant
    ON accounting_schema.expense(tenant_id);
CREATE INDEX IF NOT EXISTS idx_expense_branch
    ON accounting_schema.expense(branch_id);
CREATE INDEX IF NOT EXISTS idx_expense_date
    ON accounting_schema.expense(tenant_id, expense_date);
CREATE INDEX IF NOT EXISTS idx_expense_category
    ON accounting_schema.expense(category_id);

COMMENT ON TABLE accounting_schema.expense IS
    'Individual expense records. Each expense generates a journal entry via generateExpenseJournal().';
COMMENT ON COLUMN accounting_schema.expense.payment_method IS
    'Determines the credit account in journal entries: CASH→Caja General, BANK/TRANSFER/CHECK→Bancos, CREDIT_CARD→CxP.';

-- -------------------------------------------------------
-- 3. FISCAL PERIOD
-- -------------------------------------------------------
-- Period-based reporting. Used by Phase 4 reporteria.

CREATE TABLE IF NOT EXISTS accounting_schema.fiscal_period (
    period_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES general_schema.tenant(tenant_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_closed BOOLEAN DEFAULT FALSE,
    closed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(tenant_id, name),
    CONSTRAINT chk_period_dates CHECK (end_date > start_date)
);

CREATE INDEX IF NOT EXISTS idx_fiscal_period_tenant
    ON accounting_schema.fiscal_period(tenant_id);
CREATE INDEX IF NOT EXISTS idx_fiscal_period_dates
    ON accounting_schema.fiscal_period(tenant_id, start_date, end_date);

COMMENT ON TABLE accounting_schema.fiscal_period IS
    'Fiscal periods for financial reporting. is_closed prevents modifications to journal entries within the period.';

-- -------------------------------------------------------
-- 4. ADD EXPENSE SOURCE TYPE (if not exists)
-- -------------------------------------------------------
INSERT INTO accounting_schema.source_type(source_name, description) VALUES
('EXPENSE', 'Registro de gasto operativo')
ON CONFLICT DO NOTHING;

COMMIT;
