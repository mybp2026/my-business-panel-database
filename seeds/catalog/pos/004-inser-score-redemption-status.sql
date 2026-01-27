INSERT INTO score_redemption_status(status_name) VALUES
    ('pending'),
    ('rejected'),
    ('processed')
ON CONFLICT DO NOTHING;