INSERT INTO hr_module.paysheet_status(status_description) VALUES
('Pending'),
('Completed'),
('Canceled')
ON CONFLICT DO NOTHING;