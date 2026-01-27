INSERT INTO return_status(status_name) VALUES
    ('pending'),
    ('rejected'),
    ('processed')
ON CONFLICT DO NOTHING;
