SET SEARCH_PATH TO general_schema;

INSERT INTO general_schema.subscription_type (subscription_type_name, subscription_type_detail, duration_months, subscription_type_cost) VALUES
('Basic', 'Basic subscription plan', 1, 9.99),
('Standard', 'Standard subscription plan', 6, 49.99),
('Premium', 'Premium subscription plan', 12, 89.99)
ON CONFLICT DO NOTHING;