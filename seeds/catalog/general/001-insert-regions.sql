INSERT INTO region(region_name) VALUES
    ('Costa Rica'),
    ('Panama'),
    ('United States'),
    ('United Kingdom'),
    ('Japan')
ON CONFLICT DO NOTHING;