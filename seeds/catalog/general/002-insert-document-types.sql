SET SEARCH_PATH TO general_schema;

INSERT INTO general_schema.document_type(type_name, description) VALUES
    ('passport', 'International travel document'),
    ('driver_license', 'Official driving permit'),
    ('national_id', 'Government issued identification card')
ON CONFLICT DO NOTHING;