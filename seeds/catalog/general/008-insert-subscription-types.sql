SET search_path TO general_schema;

INSERT INTO general_schema.subscription_type (subscription_type_name, subscription_type_detail, duration_months, subscription_type_cost) VALUES
('Plan Completo', 'Acceso total a la plataforma', 1, 99.99)
ON CONFLICT DO NOTHING;
