SET SEARCH_PATH TO general_schema;

INSERT INTO general_schema.payment_method (name, description)
VALUES ('bank_transfer', 'Payment made through bank transfer')
ON CONFLICT (name) DO NOTHING;
