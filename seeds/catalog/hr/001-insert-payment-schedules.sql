INSERT INTO hr_module.payment_schedule(description, daycount) VALUES
('Monthly', 30),
('Fortnight', 15),
('Weekly', 7),
('Daily', 1)
ON CONFLICT DO NOTHING;