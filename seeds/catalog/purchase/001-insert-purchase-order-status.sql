INSERT INTO purchase_order_status(status_name, description) VALUES
('Pending', 'Order is pending'),
('Shipped', 'Order has been shipped'),
('Delivered', 'Order has been delivered'),
('Cancelled', 'Order has been cancelled')
ON CONFLICT DO NOTHING;