INSERT INTO account_payable_status(status_name, description) VALUES
('Pending', 'Payment is pending'),
('Partial Paid', 'Partial payment has been made'),
('Paid', 'Payment has been made'),
('Overdue', 'Payment is overdue')
ON CONFLICT DO NOTHING;