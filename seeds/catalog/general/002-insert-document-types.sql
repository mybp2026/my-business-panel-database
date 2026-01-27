INSERT INTO document_type(type_name, description) VALUES
    ('passport', 'International travel document'),
    ('driver_license', 'Official driving permit'),
    ('national_id', 'Government issued identification card')
ON CONFLICT DO NOTHING;