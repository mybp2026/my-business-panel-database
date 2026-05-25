SET SEARCH_PATH TO general_schema;

INSERT INTO general_schema.account_payable_type (type_name, description) VALUES
    ('goods_purchase', 'Purchases from suppliers for goods ordered'),
    ('utility_bill', 'Monthly utility bills such as electricity, water, internet'),
    ('rent_payment', 'Monthly rent payments for office or retail space'),
    ('tax_obligation', 'Taxes owed to government authorities'),
    ('loan_repayment', 'Repayments on business loans or lines of credit')
ON CONFLICT DO NOTHING;