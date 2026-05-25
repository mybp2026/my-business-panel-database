SET SEARCH_PATH TO pos_schema;

INSERT INTO pos_schema.score_transaction_type(type_name, description) VALUES
    ('earn', 'Points earned from purchases'),
    ('redeem', 'Points redeemed for rewards'),
    ('adjustment', 'Manual adjustment of points')
ON CONFLICT DO NOTHING;