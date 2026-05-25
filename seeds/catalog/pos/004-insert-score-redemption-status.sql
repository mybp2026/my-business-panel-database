SET SEARCH_PATH TO pos_schema;

INSERT INTO pos_schema.score_redemption_status(status_name) VALUES
    ('pending'),
    ('rejected'),
    ('processed')
ON CONFLICT DO NOTHING;