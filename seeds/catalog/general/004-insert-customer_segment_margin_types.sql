INSERT INTO customer_segment_margin_type(type_name, description) VALUES
    ('spending_based', 'Discounts based on total spending'),
    ('seniority_based', 'Discounts based on customer seniority'),
    ('frequency_based', 'Discounts based on a monthly basis purchase frequency'),
    ('free_selection', 'Customers can select products for free up to a limit')
ON CONFLICT DO NOTHING;