INSERT INTO customer_segment(segment_name, segment_hierarchy) VALUES
    ('vip', 1),
    ('loyal', 2),
    ('regular', 3),
    ('new', 4),
    ('inactive', 5)
ON CONFLICT DO NOTHING;