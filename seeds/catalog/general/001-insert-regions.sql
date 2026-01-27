SET SEARCH_PATH TO general_schema;

INSERT INTO general_schema.region(region_name) VALUES
    ('Costa Rica'),
    ('Panama'),
    ('United States'),
    ('United Kingdom'),
    ('Japan')
ON CONFLICT DO NOTHING;