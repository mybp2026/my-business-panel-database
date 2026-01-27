SET SEARCH_PATH TO general_schema;

INSERT INTO general_schema.role(role_name, role_hierarchy) VALUES
    ('superuser', 4),
    ('admin', 3),
    ('manager', 2),
    ('employee', 1)
ON CONFLICT DO NOTHING;