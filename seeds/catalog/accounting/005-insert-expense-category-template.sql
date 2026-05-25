-- ============================================================
-- Expense Category Template
-- ============================================================
-- Template table for expense categories, copied to per-tenant
-- expense_category via provision_tenant_expense_categories().
-- Maps each category to a chart of accounts code.
-- ============================================================

SET SEARCH_PATH TO accounting_schema;

CREATE TABLE IF NOT EXISTS accounting_schema.expense_category_template (
    template_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    account_code VARCHAR(20) NOT NULL,
    is_fixed BOOLEAN DEFAULT TRUE,
    parent_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE accounting_schema.expense_category_template IS
    'Template expense categories based on NIIF for PYMES (Costa Rica).
     Copied to expense_category per tenant via provision_tenant_expense_categories().';

TRUNCATE accounting_schema.expense_category_template RESTART IDENTITY;

INSERT INTO accounting_schema.expense_category_template(name, account_code, is_fixed, parent_name) VALUES
-- Gastos Operativos Fijos
('Salarios y Sueldos',               '5-1-001', TRUE,  NULL),
('Cargas Sociales',                   '5-1-002', TRUE,  NULL),
('Alquiler',                          '5-1-003', TRUE,  NULL),
('Servicios Públicos',                '5-1-004', TRUE,  NULL),
('Depreciación',                      '5-1-005', TRUE,  NULL),
('Seguros',                           '5-1-006', TRUE,  NULL),
('Suministros de Oficina',            '5-1-007', TRUE,  NULL),
('Mantenimiento y Reparaciones',      '5-1-008', TRUE,  NULL),
('Publicidad y Mercadeo',             '5-1-009', TRUE,  NULL),
('Gastos de Viaje',                   '5-1-010', TRUE,  NULL),

-- Gastos Financieros
('Intereses Pagados',                 '5-2-001', TRUE,  NULL),
('Comisiones Bancarias',              '5-2-002', TRUE,  NULL),
('Diferencial Cambiario',             '5-2-003', TRUE,  NULL),

-- Gastos Variables
('Comisiones por Ventas',             '5-3-001', FALSE, NULL),
('Empaque y Embalaje',                '5-3-002', FALSE, NULL),
('Transporte y Envíos',               '5-3-003', FALSE, NULL),
('Materiales de Producción',          '5-3-004', FALSE, NULL);
